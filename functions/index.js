const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

exports.onOrderUpdate = functions.firestore
  .document('orders/{orderId}')
  .onWrite(async (change, context) => {
    const after = change.after.exists ? change.after.data() : null;
    if (!after) return null;

    const status = after.status;
    const branchId = after.branch_id;
    const customerId = after.customer_id;
    const orderNumber = after.order_number;

    const tokens = [];
    const usersSnap = await admin.firestore().collection('users').get();
    usersSnap.forEach((doc) => {
      const data = doc.data();
      const token = data.fcm_token;
      if (!token) return;
      const role = data.role;
      const userBranch = data.branch_id;
      if (role === 'branchManager' && userBranch === branchId) {
        tokens.push(token);
      } else if (
        role === 'courier' &&
        status === 'waitingCourier' &&
        userBranch === branchId
      ) {
        tokens.push(token);
      } else if (doc.id === customerId) {
        tokens.push(token);
      }
    });

    if (tokens.length === 0) return null;

    return admin.messaging().sendEachForMulticast({
      tokens: [...new Set(tokens)],
      notification: {
        title: 'Tostu Sahane',
        body: `Siparis #${orderNumber} — ${status}`,
      },
      data: {
        type: 'order_update',
        order_id: context.params.orderId,
        status: status,
      },
    });
  });
