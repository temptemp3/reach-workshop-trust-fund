'reach 0.1';

/*
 * 1. Problem Analysis
 * Purpose of the application:
 * - The funder must decide an amount of fund to provide, as well as all of the other parameters of the application.
 * - The funder will know the identity of the Reciever at the beginning.
 * - Whomever ultimately receives the funds transfers it to themselves.
 * What are the participants of the application?
 * (1) Funder
 * (2) Receiver
 * (3) Bystander
 * What information do they know at the start of the program?
 * (1) Knows amt, acc of receiver, maturity, and delays before declared dormant or forsook.
 * (2,3) Know nothing
 * What information are they going to discover and use in the program?
 * (1) Discovers relay account 
 * (2,3) Learn fund existance and maturity
 * * The funds start with (1) and move to (2,1,3) depending on when they are claimed.
 * 2. Data definition
 * 3. Communication Construction
 * 1) The Funder pays amount and says who the Receiver is etc
 * 2) Concensus remembers who Reciever is
 * 3) Everyone waits for fund to mature
 * 4) Receiver may extract funds with deadline of 'refund'
 * 5) Funder may extract funds with deadline of 'dormant'
 * 6) Bystander may extract funds with no deadline 
 * 4. Assertion Insertion
 * 5. Interaction Introduction
 * 6. Deployment Decisions
 */
// -----------------------------------------------
// 1. Problem Analysis
// 2. Data definition
const common = {
  funded: Fun([], Null),
  ready: Fun([], Null),
  recvd: Fun([UInt], Null),
}
export const main = Reach.App(
  { deployMode: 'firstMsg' },
  [
    Participant('Funder', {
      ...common,
      getParams: Fun([], Object({
        receiverAddr: Address,
        payment: UInt,
        maturity: UInt,
        refund: UInt,
        dormant: UInt
      }))
    }),
    Participant('Receiver', common),
    Participant('Bystander', common)
  ],
  // 3. Communication Construction
  // 5. Interaction Introduction
  (Funder, Receiver, Bystander) => {
    // 5.1 Get Funder params
    Funder.only(() => {
      const { receiverAddr, payment, maturity, refund, dormant } =
        declassify(interact.getParams());
    });
    // 3.1 The Funder pays amount and says who the Receiver is etc
    Funder.publish(receiverAddr, payment, maturity, refund, dormant)
      .pay(payment);
    // 3.2 Concensus remembers who Reciever is
    Receiver.set(receiverAddr);
    commit();
    // 5.2 Signal funded to all participants
    each([Funder, Receiver, Bystander],() => {
      interact.funded();
    });
    // 3.3 Everyone waits for fund to mature
    wait(maturity);

    // 5.3 Determine if ready
    const giveChance = (Who, then) => {
      Who.only(() => {
        interact.ready()
      });
      if (then) {
        Who.publish()
          .timeout(then.deadline, () => then.after());
      }
      else {
        Who.publish();
      }
      transfer(payment).to(Who);
      commit();
      Who.only(() =>
        interact.recvd(payment));
      exit();
    };

    // 3.4 Receiver may extract funds with deadline of 'refund'
    giveChance(Receiver, {
      deadline: refund,
      // 3.5 Funder may extract funds with deadline of 'dormant'
      after: () => giveChance(Funder, {
        deadline: dormant,
        // 3.6 Bystander may extract funds with no deadline 
        after: () => giveChance(Bystander, false)
      })
    });

  });
