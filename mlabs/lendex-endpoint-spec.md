
# Lendex Endpoints Specification

This document describes the endpoint-level bahaviours we want to guarantee for the Lendex Contract

This will include every current/planned endpoint, and for each Endpoint, a list of:
- input type
- prerequiste actions/endpoint calls (implicit state required for the call to succeed on both wallet and script state, implied previous endpoint calls from the user)
- user role qualifications, if any
- expected effects
- known invariant effects/invalid inputs
- known risks which must be mitigated



## About the Lendex Contract

The Lendex Contract is a cardano adaptation of the Aave lending protocol.

In Aave, tokens are used to provide the infrastructure of a savings & loan bank on the blockchain.

Aave supports multiple currencies, and is mainly used to create Collateralized Debt Positions across currencies,   Aave will have individual Lendex contract instances available for each currency.

A user can deposit the currency tied to a given Lendex Contract Instance, and mint a token called an `aToken` (so for `Ada`, `aAda`, `USD`, `aUSD` etc)

These `aToken`s can then be supplied as Collateral against a loan (usually in a different currency)

when interest is paid against the loan, this increases the supply of the underlying token, while no additional aTokens are minted, the result is that aToken value has increased, as the aToken exchange rate corresponds to the ratio of (all aTokens in circulation) : (all underlying tokens in the lendex contract).

On user roles (Actor types):
Almost all users will be suppliers within the system, being a supplier is _required_ to be a borrower, though many users who act as a supplier will never be borrowers.

Additionally since LQ will be distributed among suppliers, Many (though not necessarily all) Governor users will also be suppliers.

Liquidators need not be Suppliers though.

Attackers will assume other roles, attempt to cause invariant behaviours, or take advantage of system rules such that they profit at the expense of the contract or it's users, we want to prevent these kinds of attacks or make them less profitable


## Admin Contract

### StartParams

input: Mlabs.Lending.Contract.Api.StartParams

prerequisite: none

behaviour: instantiate a User Contract with the input as its initial parameters.

### AddReserve

input: Mlabs.Lending.Contract.Api.AddReserve

Prerequisite: none

behaviour: 

-- @anton:  what does this endpoint do?

## Oracle Contract

### SetAssetPrice

input: Mlabs.Lending.Contract.Api.SetAssetPrice

prerequisite: none

behaviour: defines the conversion rate from Ada to a given Underlying token based on input values
(input specifies a `Coin` and a `Ray` (rational))

in the future we should adjust the oracle to accept information from a trusted source.

## User Contract

All Lendex endpoints rely on the Lendex being initialized through a call to `StartParams`

### Deposit

input:
Mlabs.Lending.Contract.Api.Deposit (amount, asset)

Prerequisite: wallet holds underlying currency for Market

Expected outcome: 
Wallet balance of underlying token reduces by (x * e) (plus fees).
Wallet balance of aToken increases by x.
where
  x = amount of atokens specified in request body, rounded down such that the wallet has enough underlying token (if necessary)
  e = exchange rate aToken: underlying

if this transaction deposits Ada into the contract, the stake delegation of the user should be maintained.

Invariant outcomes:
the user should not be able to call a negative number in the request body at all, and should not be able to burn tokens using the endpoint under any circumstances.

### Withdraw

input:
Mlabs.Lending.Contract.Api.Withdraw (amount, asset)

Prerequisite: The user must hold aTokens for the market in question, making the `Deposit` endpoint necessary


Expected outcome:
Wallet Balance of aToken is reduced by x.

Wallet balance of underlying is increased by (x * e) (less fees)
atokens are burned AND any global state tracking total aTokens in circulation is adjusted.

if another actor in the system has borrowed the underlying currency and paid interest, than the value of e should increase over time, this should be mechanical so it should be testable
where
  x = amount of atokens specified in request body, rounded down such that the wallet has enough aTokens (if necessary)
  e = exchange rate aToken: underlying
  
if user A calls Mint... and then a user B borrows the underlying for the market and holds the borrow for a sufficient length of time to incur interest before repaying, then repays the loan, then the exchange rate should change, meaning user A will have more funds after calling Redeem than when they called Mint...

invariant outcomes:
negative numbers used for request body should NEVER result in a mint operation, furthermore, minting of aTokens must never happen on this endpoint.

`e` must always be greater than or equal to the value of `e` at the time of the mint operation. aToken value never goes down.

other notes:


### SetUserReserveAsCollateral

input:
Mlabs.Lending.Contract.Api.SetUserReserveAsCollateral
(asset, useAsCollateral, portion)
(asset *must* refer to an aToken)

prerequisite: user must have a reserve of deposited aTokens in wallet, implying that the user has previously called `Deposit`

collateral ratios are calculated using each aToken : underlying exchange rate, then the exchange rate between that underlying token and Ada, which is provided by the Oracle - this way the collateral and the borrowed currency can be compared via relative value in Ada.

behavior:
let `userTokens` equal amount of `asset` in user wallet / provided utxos
let `contractTokens` equal amount of `asset` currently locked as collateral for this user
if useAsCollateral is True, then move (`userTokens` of `asset` * `portion`) from User wallet to contract and lock as collateral
if useAsCollateral is false, then move (`contractTokens` of `asset` * `portion`) from contract to user wallet rounding down to ensure that the user does not go below minimum collateral ratios for this Lendex/User contract

@anton - why is the `useAsCollateral` flag necessary? the Api for this endpoint feels a bit strange

`asset` must refer to a supported token for this Lendex

### Borrow

Input:
Mlabs.Lending.Contract.Api.Borrow
(amount, asset, rate)
 

Users: Borrowers

Prerequisite:
the user must have an appropriate amount of aTokens already held in the contract Collateral such that their borrow specifications can be met without putting them below minimum collateral Ratio

collateral ratios are calculated using each aToken : underlying exchange rate, then the exchange rate between that underlying token and Ada, which is provided by the Oracle - this way the collateral and the borrowed currency can be compared via relative value in Ada.

expected outcomes:
- interest must be advanced on any outstanding borrows for this user - all calculations must use this amount and not the pre-interest amount.

- wallet of user balance increases in `amount` of the Lendex's underlying token.
- sufficient state must be maintained such that the user's outstanding borrow can always be known or accurately calculated, including interest.
- if the user has existing borrows against their collateral, this must be considered as well such that the user's maximum borrow amount is never exceeded, interest should be recalculated before this check as well if needed.

invariant behaviours:
the user should not be able to specify negative amounts to borrow or provide collateral.  there should be no input such that this endpoint releases collateral to the user.

Attack Vectors:

Market Manipulation
a user may attempt to manipulate the market or tamper with oracle behavior, being able to take out a loan during a price fluctuation (where the value of the underlying Token being borrowed is moved down, or the value of the collateral is move upward) allowing a borrow of more funds than the collateral provided once prices normalize

This may require mitigation with time-weighted-averaging to the contract's benefit. 

### Repay

input:
Mlabs.Lending.Contract.Api.Repay
(amount, asset, rate)

Users: Borrowers

Prerequisite: 
the user must have a loan, and in general will have Collateral to secure the loan up to the collateralRatio for the Lendex

there are edge cases where we are unable to liquidate or have not yet liquidated the user, and they repay a portion of the loan, saving the loan from liquidation.

expected outcomes
interest against the loan should be recalculated.
the wallet of the user will decrease by the specified amount from input in the Market's underlying Currency (or round down if the amount available is less than the amount in the input)
the outstanding loan payment will be reduced by the amount paid, less interest applied against the loan
Collateral is not released on this endpoint, even if the borrow amount is totally paid off.

if repaying Ada, the user's stake delegation should be changed to some default? - if this feature is available in plutus

invariant outcomes:
can't repay a negative amount but 0 is ok.

### SwapBorrowRateModel

### LiquidationCall

