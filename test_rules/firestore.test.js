const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const fs = require("fs");
const firebase = require("firebase/compat/app");
require("firebase/compat/firestore");

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "trade-crypto-test",
    firestore: {
      rules: fs.readFileSync("firestore.rules", "utf8"),
      host: "localhost",
      port: 8080,
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

describe("Firestore Security Rules", () => {
  const aliceId = "alice";
  const bobId = "bob";
  const validClosedTrade = () => ({
    type: "Buy",
    coinId: "bitcoin",
    coinName: "Bitcoin",
    coinSymbol: "btc",
    coinImage: "https://example.com/bitcoin.png",
    amount: 1,
    entryPrice: 100,
    exitPrice: 110,
    cost: 100,
    realizedPnl: 10,
    closeReason: "manual",
    openedAt: firebase.firestore.Timestamp.fromDate(new Date("2026-01-01T00:00:00Z")),
    closedAt: firebase.firestore.FieldValue.serverTimestamp(),
  });

  test("owner can read own user doc", async () => {
    const db = testEnv.authenticatedContext(aliceId, { email: "alice@test.com" }).firestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc(aliceId).set({
        name: "Alice",
        phone: "123456",
        email: "alice@test.com",
        wallet: 10000,
      });
    });

    await assertSucceeds(db.collection("users").doc(aliceId).get());
  });

  test("unauthenticated user cannot read user doc", async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc(aliceId).set({
        name: "Alice",
        phone: "123456",
        email: "alice@test.com",
        wallet: 10000,
      });
    });

    await assertFails(db.collection("users").doc(aliceId).get());
  });

  test("another user cannot read user doc", async () => {
    const db = testEnv.authenticatedContext(bobId, { email: "bob@test.com" }).firestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc(aliceId).set({
        name: "Alice",
        phone: "123456",
        email: "alice@test.com",
        wallet: 10000,
      });
    });

    await assertFails(db.collection("users").doc(aliceId).get());
  });

  test("another user cannot read someone's transactions", async () => {
    const db = testEnv.authenticatedContext(bobId, { email: "bob@test.com" }).firestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc(aliceId).collection("transactions").doc("tx1").set({
        type: "Buy",
        coinId: "bitcoin",
        amount: 1,
        price: 50000,
        cost: 50000,
        date: new Date().toISOString(),
      });
    });

    await assertFails(db.collection("users").doc(aliceId).collection("transactions").doc("tx1").get());
  });

  test("owner cannot delete their user doc", async () => {
    const db = testEnv.authenticatedContext(aliceId, { email: "alice@test.com" }).firestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc(aliceId).set({
        name: "Alice",
        phone: "123456",
        email: "alice@test.com",
        wallet: 10000,
      });
    });

    await assertFails(db.collection("users").doc(aliceId).delete());
  });

  test("user create succeeds with wallet 10000 and matching token email", async () => {
    const db = testEnv.authenticatedContext(aliceId, { email: "alice@test.com" }).firestore();
    const userRef = db.collection("users").doc(aliceId);

    await assertSucceeds(
      userRef.set({
        name: "Alice",
        phone: "123456",
        email: "alice@test.com",
        wallet: 10000,
      })
    );
  });

  test("user create fails with mismatched token email", async () => {
    const db = testEnv.authenticatedContext(aliceId, { email: "mismatch@test.com" }).firestore();
    const userRef = db.collection("users").doc(aliceId);

    await assertFails(
      userRef.set({
        name: "Alice",
        phone: "123456",
        email: "alice@test.com",
        wallet: 10000,
      })
    );
  });

  test("user create fails with wallet 99999", async () => {
    const db = testEnv.authenticatedContext(aliceId, { email: "alice@test.com" }).firestore();
    const userRef = db.collection("users").doc(aliceId);

    await assertFails(
      userRef.set({
        name: "Alice",
        phone: "123456",
        email: "alice@test.com",
        wallet: 99999,
      })
    );
  });

  test("user create fails with extra field", async () => {
    const db = testEnv.authenticatedContext(aliceId, { email: "alice@test.com" }).firestore();
    const userRef = db.collection("users").doc(aliceId);

    await assertFails(
      userRef.set({
        name: "Alice",
        phone: "123456",
        email: "alice@test.com",
        wallet: 10000,
        extra: "bad",
      })
    );
  });

  test("client can change name and phone", async () => {
    const db = testEnv.authenticatedContext(aliceId, { email: "alice@test.com" }).firestore();
    const userRef = db.collection("users").doc(aliceId);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc(aliceId).set({
        name: "Alice",
        phone: "123456",
        email: "alice@test.com",
        wallet: 10000,
      });
    });

    await assertSucceeds(
      userRef.update({
        name: "Alice Updated",
        phone: "654321",
      })
    );
  });

  test("update with an extra key fails", async () => {
    const db = testEnv.authenticatedContext(aliceId, { email: "alice@test.com" }).firestore();
    const userRef = db.collection("users").doc(aliceId);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc(aliceId).set({
        name: "Alice",
        phone: "123456",
        email: "alice@test.com",
        wallet: 10000,
      });
    });

    await assertFails(
      userRef.update({
        name: "Alice Updated",
        email: "hacked@test.com",
      })
    );
  });

  test("name of 101 characters fails", async () => {
    const db = testEnv.authenticatedContext(aliceId, { email: "alice@test.com" }).firestore();
    const userRef = db.collection("users").doc(aliceId);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc(aliceId).set({
        name: "Alice",
        phone: "123456",
        email: "alice@test.com",
        wallet: 10000,
      });
    });

    const longName = "a".repeat(101);
    await assertFails(
      userRef.update({
        name: longName,
      })
    );
  });

  test("non-string phone fails", async () => {
    const db = testEnv.authenticatedContext(aliceId, { email: "alice@test.com" }).firestore();
    const userRef = db.collection("users").doc(aliceId);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc(aliceId).set({
        name: "Alice",
        phone: "123456",
        email: "alice@test.com",
        wallet: 10000,
      });
    });

    await assertFails(
      userRef.update({
        phone: 123456,
      })
    );
  });

  test("client can change wallet within bounds, but wallet -1 and wallet 2000000000 fail", async () => {
    const db = testEnv.authenticatedContext(aliceId, { email: "alice@test.com" }).firestore();
    const userRef = db.collection("users").doc(aliceId);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc(aliceId).set({
        name: "Alice",
        phone: "123456",
        email: "alice@test.com",
        wallet: 10000,
      });
    });

    await assertSucceeds(
      userRef.update({
        wallet: 15000,
      })
    );

    await assertFails(
      userRef.update({
        wallet: -1,
      })
    );

    await assertFails(
      userRef.update({
        wallet: 2000000000,
      })
    );
  });

  test("owner can create a valid transaction, cannot create one with amount 0 or type 'Hold', cannot update it, can delete it; another user can do none of these", async () => {
    const aliceDb = testEnv.authenticatedContext(aliceId, { email: "alice@test.com" }).firestore();
    const bobDb = testEnv.authenticatedContext(bobId, { email: "bob@test.com" }).firestore();

    const txRef = aliceDb.collection("users").doc(aliceId).collection("transactions").doc("tx1");
    const bobTxRef = bobDb.collection("users").doc(aliceId).collection("transactions").doc("tx1");

    await assertSucceeds(
      txRef.set({
        type: "Buy",
        coinId: "bitcoin",
        amount: 1,
        price: 50000,
        cost: 50000,
        date: new Date().toISOString(),
      })
    );

    await assertFails(
      bobTxRef.set({
        type: "Buy",
        coinId: "bitcoin",
        amount: 1,
        price: 50000,
        cost: 50000,
        date: new Date().toISOString(),
      })
    );

    await assertFails(
      aliceDb.collection("users").doc(aliceId).collection("transactions").doc("txZero").set({
        type: "Buy",
        coinId: "bitcoin",
        amount: 0,
        price: 50000,
        cost: 0,
        date: new Date().toISOString(),
      })
    );

    await assertFails(
      aliceDb.collection("users").doc(aliceId).collection("transactions").doc("txHold").set({
        type: "Hold",
        coinId: "bitcoin",
        amount: 1,
        price: 50000,
        cost: 50000,
        date: new Date().toISOString(),
      })
    );

    await assertSucceeds(txRef.get());
    await assertFails(bobTxRef.get());

    await assertFails(txRef.update({ amount: 2 }));
    await assertFails(bobTxRef.update({ amount: 2 }));

    await assertFails(bobTxRef.delete());
    await assertSucceeds(txRef.delete());
  });

  test("owner can create, read, re-add, and delete a valid watchlist coin", async () => {
    const db = testEnv.authenticatedContext(aliceId).firestore();
    const coinRef = db.collection("users").doc(aliceId).collection("watchlist").doc("bitcoin");
    const coin = {
      name: "Bitcoin",
      symbol: "btc",
      image: "https://example.com/bitcoin.png",
    };

    await assertSucceeds(coinRef.set(coin));
    await assertSucceeds(coinRef.get());
    await assertSucceeds(coinRef.set(coin));
    await assertSucceeds(coinRef.delete());
  });

  test("another user and unauthenticated users cannot access a watchlist", async () => {
    const ownerDb = testEnv.authenticatedContext(aliceId).firestore();
    const otherDb = testEnv.authenticatedContext(bobId).firestore();
    const unauthenticatedDb = testEnv.unauthenticatedContext().firestore();
    const coin = {
      name: "Bitcoin",
      symbol: "btc",
      image: "https://example.com/bitcoin.png",
    };
    const ownerCoin = ownerDb.collection("users").doc(aliceId).collection("watchlist").doc("bitcoin");
    const otherCoin = otherDb.collection("users").doc(aliceId).collection("watchlist").doc("bitcoin");
    const otherCreateCoin = otherDb.collection("users").doc(aliceId).collection("watchlist").doc("other-create");
    const unauthenticatedCoin = unauthenticatedDb.collection("users").doc(aliceId).collection("watchlist").doc("bitcoin");
    const unauthenticatedCreateCoin = unauthenticatedDb.collection("users").doc(aliceId).collection("watchlist").doc("unauthenticated-create");

    await assertSucceeds(ownerCoin.set(coin));
    await assertFails(otherCoin.get());
    await assertFails(otherCreateCoin.set(coin));
    await assertFails(otherCoin.update({ name: "Other" }));
    await assertFails(otherCoin.delete());
    await assertFails(unauthenticatedCoin.get());
    await assertFails(unauthenticatedCreateCoin.set(coin));
    await assertFails(unauthenticatedCoin.update({ name: "Other" }));
    await assertFails(unauthenticatedCoin.delete());
  });

  test("watchlist rejects invalid coin IDs", async () => {
    const db = testEnv.authenticatedContext(aliceId).firestore();
    const watchlist = db.collection("users").doc(aliceId).collection("watchlist");

    await assertFails(
      watchlist.doc("BAD ID!").set({
        name: "Bitcoin",
        symbol: "btc",
        image: "https://example.com/bitcoin.png",
      })
    );
  });

  test("watchlist rejects invalid fields and oversized values on create and update", async () => {
    const db = testEnv.authenticatedContext(aliceId).firestore();
    const watchlist = db.collection("users").doc(aliceId).collection("watchlist");
    const coin = {
      name: "Bitcoin",
      symbol: "btc",
      image: "https://example.com/bitcoin.png",
    };

    await assertFails(
      watchlist.doc("invalid-name").set({
        name: 123,
        symbol: "btc",
        image: "",
      })
    );
    await assertFails(
      watchlist.doc("extra-field-create").set({
        ...coin,
        wallet: 10000,
      })
    );
    await assertFails(
      watchlist.doc("missing-field-create").set({
        name: "Bitcoin",
        symbol: "btc",
      })
    );
    await assertFails(
      watchlist.doc("long-name").set({
        name: "a".repeat(101),
        symbol: "btc",
        image: "",
      })
    );

    const extraFieldUpdate = watchlist.doc("extra-field-update");
    await assertSucceeds(extraFieldUpdate.set(coin));
    await assertFails(extraFieldUpdate.set({ ...coin, wallet: 10000 }));

    const missingFieldUpdate = watchlist.doc("missing-field-update");
    await assertSucceeds(missingFieldUpdate.set(coin));
    await assertFails(
      missingFieldUpdate.set({
        name: "Bitcoin",
        symbol: "btc",
      })
    );
  });

  test("owner can create, read, and delete assistant messages but cannot update them", async () => {
    const db = testEnv.authenticatedContext(aliceId).firestore();
    const messageRef = db.collection("users").doc(aliceId).collection("assistantMessages").doc("message-1");
    const message = {
      role: "user",
      text: "Analyze my Bitcoin position.",
      createdAt: firebase.firestore.FieldValue.serverTimestamp(),
    };

    await assertSucceeds(messageRef.set(message));
    await assertSucceeds(messageRef.get());
    await assertFails(messageRef.update({ text: "Review my Bitcoin position." }));
    await assertSucceeds(messageRef.delete());
  });

  test("another user cannot access assistant messages", async () => {
    const ownerDb = testEnv.authenticatedContext(aliceId).firestore();
    const otherDb = testEnv.authenticatedContext(bobId).firestore();
    const message = {
      role: "assistant",
      text: "Your position has these risks.",
      createdAt: firebase.firestore.FieldValue.serverTimestamp(),
    };
    const ownerMessage = ownerDb.collection("users").doc(aliceId).collection("assistantMessages").doc("message-1");
    const otherMessage = otherDb.collection("users").doc(aliceId).collection("assistantMessages").doc("message-1");
    const otherCreate = otherDb.collection("users").doc(aliceId).collection("assistantMessages").doc("message-2");

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc(aliceId).collection("assistantMessages").doc("message-1").set(message);
    });

    await assertFails(otherMessage.get());
    await assertFails(otherCreate.set(message));
    await assertFails(otherMessage.update({ text: "Changed" }));
    await assertFails(otherMessage.delete());
    await assertSucceeds(ownerMessage.get());
  });

  test("unauthenticated users cannot access assistant messages", async () => {
    const ownerDb = testEnv.authenticatedContext(aliceId).firestore();
    const unauthenticatedDb = testEnv.unauthenticatedContext().firestore();
    const message = {
      role: "user",
      text: "What are the risks?",
      createdAt: firebase.firestore.FieldValue.serverTimestamp(),
    };
    const ownerMessage = ownerDb.collection("users").doc(aliceId).collection("assistantMessages").doc("message-1");
    const unauthenticatedMessage = unauthenticatedDb.collection("users").doc(aliceId).collection("assistantMessages").doc("message-1");
    const unauthenticatedCreate = unauthenticatedDb.collection("users").doc(aliceId).collection("assistantMessages").doc("message-2");

    await assertSucceeds(ownerMessage.set(message));
    await assertFails(unauthenticatedMessage.get());
    await assertFails(unauthenticatedCreate.set(message));
    await assertFails(unauthenticatedMessage.update({ text: "Changed" }));
    await assertFails(unauthenticatedMessage.delete());
  });

  test("owner can create a valid closed trade", async () => {
    const db = testEnv.authenticatedContext(aliceId).firestore();
    const closedTrade = db.collection("users").doc(aliceId).collection("closedTrades").doc("trade-1");

    await assertSucceeds(closedTrade.set(validClosedTrade()));
    await assertSucceeds(closedTrade.get());
  });

  test("another user cannot create a closed trade for the owner", async () => {
    const db = testEnv.authenticatedContext(bobId).firestore();
    const closedTrade = db.collection("users").doc(aliceId).collection("closedTrades").doc("trade-1");

    await assertFails(closedTrade.set(validClosedTrade()));
  });

  test("closed trades reject extra fields and invalid close reasons", async () => {
    const db = testEnv.authenticatedContext(aliceId).firestore();
    const trades = db.collection("users").doc(aliceId).collection("closedTrades");

    await assertFails(trades.doc("extra-field").set({
      ...validClosedTrade(),
      extra: "not allowed",
    }));
    await assertFails(trades.doc("bad-reason").set({
      ...validClosedTrade(),
      closeReason: "automatic",
    }));
  });

  test("closed trades cannot be updated or deleted", async () => {
    const db = testEnv.authenticatedContext(aliceId).firestore();
    const closedTrade = db.collection("users").doc(aliceId).collection("closedTrades").doc("trade-1");

    await assertSucceeds(closedTrade.set(validClosedTrade()));
    await assertFails(closedTrade.update({ realizedPnl: 99 }));
    await assertFails(closedTrade.delete());
  });

  test("owner can read and increment assistant usage by one", async () => {
    const db = testEnv.authenticatedContext(aliceId).firestore();
    const usage = db.collection("users").doc(aliceId).collection("assistantUsage").doc("2026-11-26");

    await assertSucceeds(usage.set({ count: 1 }));
    await assertSucceeds(usage.get());
    await assertSucceeds(usage.update({ count: 2 }));
    await assertFails(usage.update({ count: 4 }));
    await assertFails(usage.update({ count: 1 }));
    await assertFails(usage.delete());
  });

  test("assistant usage counters reject invalid counts", async () => {
    const db = testEnv.authenticatedContext(aliceId).firestore();
    const usage = db.collection("users").doc(aliceId).collection("assistantUsage");

    await assertFails(usage.doc("zero").set({ count: 0 }));
    await assertFails(usage.doc("large").set({ count: 101 }));
    await assertFails(usage.doc("string").set({ count: "1" }));

    const maximum = usage.doc("maximum");
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc(aliceId)
        .collection("assistantUsage").doc("maximum").set({ count: 100 });
    });
    await assertFails(maximum.update({ count: 101 }));
  });

  test("assistant usage counters are private to their owner", async () => {
    const ownerDb = testEnv.authenticatedContext(aliceId).firestore();
    const otherDb = testEnv.authenticatedContext(bobId).firestore();
    const unauthenticatedDb = testEnv.unauthenticatedContext().firestore();
    const ownerUsage = ownerDb.collection("users").doc(aliceId).collection("assistantUsage").doc("2026-11-26");
    const otherUsage = otherDb.collection("users").doc(aliceId).collection("assistantUsage").doc("2026-11-26");
    const otherCreate = otherDb.collection("users").doc(aliceId).collection("assistantUsage").doc("2026-11-27");
    const unauthenticatedUsage = unauthenticatedDb.collection("users").doc(aliceId).collection("assistantUsage").doc("2026-11-26");
    const unauthenticatedCreate = unauthenticatedDb.collection("users").doc(aliceId).collection("assistantUsage").doc("2026-11-27");

    await assertSucceeds(ownerUsage.set({ count: 1 }));
    await assertFails(otherUsage.get());
    await assertFails(otherCreate.set({ count: 1 }));
    await assertFails(otherUsage.update({ count: 2 }));
    await assertFails(otherUsage.delete());
    await assertFails(unauthenticatedUsage.get());
    await assertFails(unauthenticatedCreate.set({ count: 1 }));
    await assertFails(unauthenticatedUsage.update({ count: 2 }));
    await assertFails(unauthenticatedUsage.delete());
  });

  test("assistant messages reject backdated createdAt values", async () => {
    const db = testEnv.authenticatedContext(aliceId).firestore();
    const messageRef = db.collection("users").doc(aliceId).collection("assistantMessages").doc("backdated");

    await assertFails(messageRef.set({
      role: "user",
      text: "Backdated message",
      createdAt: new Date(Date.now() - 60000),
    }));
  });

  test("assistant messages reject invalid data", async () => {
    const db = testEnv.authenticatedContext(aliceId).firestore();
    const messages = db.collection("users").doc(aliceId).collection("assistantMessages");

    await assertFails(messages.doc("invalid-role").set({
      role: "system",
      text: "Invalid role",
      createdAt: firebase.firestore.FieldValue.serverTimestamp(),
    }));
    await assertFails(messages.doc("extra-field").set({
      role: "user",
      text: "Extra field",
      createdAt: firebase.firestore.FieldValue.serverTimestamp(),
      ownerId: aliceId,
    }));
    await assertFails(messages.doc("invalid-time").set({
      role: "user",
      text: "Invalid timestamp",
      createdAt: "now",
    }));
  });
});
