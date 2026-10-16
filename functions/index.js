const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Helper to verify caller is authenticated
 */
function assertAuthenticated(auth) {
  if (!auth || !auth.uid) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }
}

/**
 * Helper to check if caller has admin or staff privileges
 */
async function assertStaffOrAdmin(auth) {
  assertAuthenticated(auth);
  if (auth.token && (auth.token.role === "admin" || auth.token.admin === true || auth.token.role === "staff")) {
    return true;
  }
  const userDoc = await db.collection("users").doc(auth.uid).get();
  if (userDoc.exists) {
    const role = userDoc.data().role;
    if (role === "admin" || role === "staff") {
      return true;
    }
  }
  throw new HttpsError("permission-denied", "Insufficient permissions to perform this operation.");
}

/**
 * Helper to log audit activities
 */
async function logActivity(actorId, actorName, action, category, details, targetId = null) {
  try {
    await db.collection("activity_logs").add({
      actorId,
      actorName: actorName || "System/Admin",
      action,
      category,
      details,
      targetId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (err) {
    console.error("Failed to write activity log:", err);
  }
}

/**
 * 1. Bootstrap First Administrator
 * Ensures first account setup can claim admin role securely without hardcoded credentials.
 */
exports.bootstrapAdmin = onCall(async (request) => {
  assertAuthenticated(request.auth);
  const uid = request.auth.uid;
  const email = request.auth.token.email || "";

  // Check if any admin already exists in the system
  const adminUsers = await db.collection("users").where("role", "==", "admin").limit(1).get();
  if (!adminUsers.empty && adminUsers.docs[0].id !== uid) {
    throw new HttpsError("failed-precondition", "An administrator already exists. Contact existing admin to assign roles.");
  }

  // Set custom claims and update user document
  await admin.auth().setCustomUserClaims(uid, { role: "admin", admin: true });
  await db.collection("users").doc(uid).set({
    email,
    name: request.data.name || email.split("@")[0] || "Administrator",
    role: "admin",
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  await logActivity(uid, email, "BOOTSTRAP_ADMIN", "SECURITY", "Initial admin setup executed.", uid);

  return { success: true, message: `User ${email} has been granted administrator role.` };
});

/**
 * 2. Create Invoice
 * Server recalculates items, subtotals, discounts, and assigns sequential invoice number.
 */
exports.createInvoice = onCall(async (request) => {
  await assertStaffOrAdmin(request.auth);
  const data = request.data;
  const { customerId, serviceId, items, discount = 0, dueDate, notes = "" } = data;

  if (!customerId || !Array.isArray(items) || items.length === 0) {
    throw new HttpsError("invalid-argument", "Customer ID and valid invoice items are required.");
  }

  // Calculate items total safely on server
  let subtotal = 0;
  const validatedItems = items.map((item, idx) => {
    const unitPrice = Math.round(Number(item.unitPrice) || 0);
    const quantity = Math.max(1, Math.round(Number(item.quantity) || 1));
    const itemTotal = unitPrice * quantity;
    if (unitPrice < 0) {
      throw new HttpsError("invalid-argument", `Item #${idx + 1} unit price cannot be negative.`);
    }
    subtotal += itemTotal;
    return {
      description: String(item.description || "Layanan VPS"),
      unitPrice,
      quantity,
      total: itemTotal,
    };
  });

  const discountAmount = Math.max(0, Math.round(Number(discount) || 0));
  const total = Math.max(0, subtotal - discountAmount);

  // Generate unique sequential invoice number: INV-YYYYMM-XXXX
  const now = new Date();
  const yearMonth = `${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, "0")}`;
  const counterRef = db.collection("app_settings").doc("invoice_counter");

  const invoiceResult = await db.runTransaction(async (transaction) => {
    const counterDoc = await transaction.get(counterRef);
    let nextNum = 1;
    if (counterDoc.exists && counterDoc.data()[yearMonth]) {
      nextNum = Number(counterDoc.data()[yearMonth]) + 1;
    }
    transaction.set(counterRef, { [yearMonth]: nextNum }, { merge: true });

    const invoiceNumber = `INV-${yearMonth}-${String(nextNum).padStart(4, "0")}`;
    const invoiceRef = db.collection("invoices").doc();

    const invoiceDoc = {
      id: invoiceRef.id,
      invoiceNumber,
      customerId,
      serviceId: serviceId || null,
      items: validatedItems,
      subtotal,
      discount: discountAmount,
      total,
      paidAmount: 0,
      status: "unpaid",
      issuedAt: admin.firestore.FieldValue.serverTimestamp(),
      dueDate: dueDate ? admin.firestore.Timestamp.fromDate(new Date(dueDate)) : admin.firestore.Timestamp.fromDate(new Date(Date.now() + 7 * 86400000)),
      notes,
      createdBy: request.auth.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    transaction.set(invoiceRef, invoiceDoc);
    return invoiceDoc;
  });

  await logActivity(
    request.auth.uid,
    request.auth.token.email,
    "CREATE_INVOICE",
    "FINANCE",
    `Created invoice ${invoiceResult.invoiceNumber} for amount Rp${total}`,
    invoiceResult.id
  );

  return { success: true, invoice: invoiceResult };
});

/**
 * 3. Record Payment
 * Applies payment with idempotency key, handles partial and full payments safely using transactions.
 */
exports.recordPayment = onCall(async (request) => {
  await assertStaffOrAdmin(request.auth);
  const { invoiceId, amount, paymentMethod, referenceNumber = "", notes = "", idempotencyKey } = request.data;

  const paymentAmount = Math.round(Number(amount) || 0);
  if (!invoiceId || paymentAmount <= 0) {
    throw new HttpsError("invalid-argument", "Valid invoiceId and positive payment amount are required.");
  }

  // Idempotency check if key provided
  if (idempotencyKey) {
    const existing = await db.collection("payments").where("idempotencyKey", "==", idempotencyKey).limit(1).get();
    if (!existing.empty) {
      return { success: true, duplicate: true, payment: existing.docs[0].data() };
    }
  }

  const invoiceRef = db.collection("invoices").doc(invoiceId);

  const result = await db.runTransaction(async (transaction) => {
    const invoiceSnap = await transaction.get(invoiceRef);
    if (!invoiceSnap.exists) {
      throw new HttpsError("not-found", `Invoice ${invoiceId} not found.`);
    }

    const inv = invoiceSnap.data();
    if (inv.status === "cancelled") {
      throw new HttpsError("failed-precondition", "Cannot pay a cancelled invoice.");
    }

    const currentPaid = Number(inv.paidAmount) || 0;
    const invoiceTotal = Number(inv.total) || 0;
    const remaining = Math.max(0, invoiceTotal - currentPaid);

    if (remaining <= 0 && inv.status === "paid") {
      throw new HttpsError("failed-precondition", "Invoice is already fully paid.");
    }

    const newPaidAmount = currentPaid + paymentAmount;
    const newStatus = newPaidAmount >= invoiceTotal ? "paid" : "partial";

    const paymentRef = db.collection("payments").doc();
    const paymentRecord = {
      id: paymentRef.id,
      invoiceId,
      customerId: inv.customerId,
      serviceId: inv.serviceId || null,
      amount: paymentAmount,
      paymentDate: admin.firestore.FieldValue.serverTimestamp(),
      paymentMethod: paymentMethod || "Transfer Bank",
      referenceNumber,
      recordedBy: request.auth.uid,
      notes,
      idempotencyKey: idempotencyKey || null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    transaction.set(paymentRef, paymentRecord);
    transaction.update(invoiceRef, {
      paidAmount: newPaidAmount,
      status: newStatus,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { payment: paymentRecord, newPaidAmount, newStatus, invoiceNumber: inv.invoiceNumber };
  });

  await logActivity(
    request.auth.uid,
    request.auth.token.email,
    "RECORD_PAYMENT",
    "FINANCE",
    `Payment Rp${paymentAmount} recorded for invoice ${result.invoiceNumber} (Status: ${result.newStatus})`,
    result.payment.id
  );

  return { success: true, payment: result.payment, invoiceStatus: result.newStatus };
});

/**
 * 4. Reverse Payment
 * Reverses a payment, recalculating invoice balance, maintaining audit history.
 */
exports.reversePayment = onCall(async (request) => {
  await assertStaffOrAdmin(request.auth);
  const { paymentId, reason = "" } = request.data;

  if (!paymentId) {
    throw new HttpsError("invalid-argument", "Payment ID is required.");
  }

  const paymentRef = db.collection("payments").doc(paymentId);

  const result = await db.runTransaction(async (transaction) => {
    const paymentSnap = await transaction.get(paymentRef);
    if (!paymentSnap.exists) {
      throw new HttpsError("not-found", "Payment record not found.");
    }

    const pay = paymentSnap.data();
    if (pay.isReversed) {
      throw new HttpsError("failed-precondition", "This payment has already been reversed.");
    }

    const invoiceRef = db.collection("invoices").doc(pay.invoiceId);
    const invoiceSnap = await transaction.get(invoiceRef);
    if (!invoiceSnap.exists) {
      throw new HttpsError("not-found", "Associated invoice not found.");
    }

    const inv = invoiceSnap.data();
    const currentPaid = Number(inv.paidAmount) || 0;
    const newPaidAmount = Math.max(0, currentPaid - pay.amount);
    const invoiceTotal = Number(inv.total) || 0;

    let newStatus = "unpaid";
    if (newPaidAmount >= invoiceTotal && invoiceTotal > 0) {
      newStatus = "paid";
    } else if (newPaidAmount > 0) {
      newStatus = "partial";
    }

    transaction.update(paymentRef, {
      isReversed: true,
      reversedAt: admin.firestore.FieldValue.serverTimestamp(),
      reversedBy: request.auth.uid,
      reverseReason: reason,
    });

    transaction.update(invoiceRef, {
      paidAmount: newPaidAmount,
      status: newStatus,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { pay, newPaidAmount, newStatus, invoiceNumber: inv.invoiceNumber };
  });

  await logActivity(
    request.auth.uid,
    request.auth.token.email,
    "REVERSE_PAYMENT",
    "FINANCE",
    `Reversed payment ${paymentId} (Rp${result.pay.amount}) for invoice ${result.invoiceNumber}. Reason: ${reason}`,
    paymentId
  );

  return { success: true, message: "Payment reversed successfully.", newStatus: result.newStatus };
});

/**
 * 5. Renew VPS Service
 * Extends expiration date idempotenly, updates status to active, logs renewal history.
 */
exports.renewService = onCall(async (request) => {
  await assertStaffOrAdmin(request.auth);
  const { serviceId, durationMonths = 1, invoiceId, idempotencyKey, notes = "" } = request.data;

  const months = Math.max(1, Math.round(Number(durationMonths) || 1));
  if (!serviceId) {
    throw new HttpsError("invalid-argument", "Service ID is required.");
  }

  // Idempotency check
  if (idempotencyKey) {
    const existing = await db.collection("service_renewals").where("idempotencyKey", "==", idempotencyKey).limit(1).get();
    if (!existing.empty) {
      return { success: true, duplicate: true, renewal: existing.docs[0].data() };
    }
  }

  const serviceRef = db.collection("vps_services").doc(serviceId);

  const result = await db.runTransaction(async (transaction) => {
    const serviceSnap = await transaction.get(serviceRef);
    if (!serviceSnap.exists) {
      throw new HttpsError("not-found", "VPS Service not found.");
    }

    const svc = serviceSnap.data();
    const oldEndDate = svc.endDate ? svc.endDate.toDate() : new Date();
    const now = new Date();

    // If existing end date is still in future, extend from that date.
    // If already expired, start from today.
    const baseDate = oldEndDate > now ? new Date(oldEndDate.getTime()) : new Date(now.getTime());
    const newEndDate = new Date(baseDate.setMonth(baseDate.getMonth() + months));

    const renewalRef = db.collection("service_renewals").doc();
    const renewalRecord = {
      id: renewalRef.id,
      serviceId,
      customerId: svc.customerId,
      previousEndDate: admin.firestore.Timestamp.fromDate(oldEndDate),
      newEndDate: admin.firestore.Timestamp.fromDate(newEndDate),
      durationMonths: months,
      invoiceId: invoiceId || null,
      adminId: request.auth.uid,
      notes,
      idempotencyKey: idempotencyKey || null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    transaction.set(renewalRef, renewalRecord);
    transaction.update(serviceRef, {
      endDate: admin.firestore.Timestamp.fromDate(newEndDate),
      status: "active",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { renewal: renewalRecord, newEndDate, serviceName: svc.serviceName || svc.domain };
  });

  await logActivity(
    request.auth.uid,
    request.auth.token.email,
    "RENEW_SERVICE",
    "SERVICES",
    `Renewed service ${result.serviceName} (+${months} months) until ${result.newEndDate.toISOString().split("T")[0]}`,
    result.renewal.id
  );

  return { success: true, renewal: result.renewal };
});

/**
 * 6. Scheduled Check for Expiring VPS Services
 * Runs daily or can be triggered to send notifications for services expiring in 30, 14, 7, 3, 1 days.
 */
exports.checkExpiringServices = onSchedule("every 24 hours", async (event) => {
  const now = new Date();
  const intervals = [30, 14, 7, 3, 1];

  for (const days of intervals) {
    const targetDate = new Date(now.getTime() + days * 86400000);
    const startOfTarget = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate(), 0, 0, 0);
    const endOfTarget = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate(), 23, 59, 59);

    const snapshot = await db.collection("vps_services")
      .where("status", "in", ["active", "actice"])
      .where("endDate", ">=", admin.firestore.Timestamp.fromDate(startOfTarget))
      .where("endDate", "<=", admin.firestore.Timestamp.fromDate(endOfTarget))
      .get();

    for (const doc of snapshot.docs) {
      const svc = doc.data();
      await db.collection("notifications").add({
        title: `Layanan Mendekati Jatuh Tempo (${days} Hari)`,
        message: `VPS ${svc.serviceName || svc.domain} akan berakhir pada ${svc.endDate.toDate().toLocaleDateString("id-ID")}.`,
        category: "EXPIRATION",
        serviceId: doc.id,
        customerId: svc.customerId,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  }
});
