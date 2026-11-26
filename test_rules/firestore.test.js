const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const fs = require("fs");

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
});
