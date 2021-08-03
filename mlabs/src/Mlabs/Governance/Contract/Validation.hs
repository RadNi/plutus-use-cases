-- | Validation, on-chain code for governance application 
module Mlabs.Governance.Contract.Validation (
    scrAddress
  , scrInstance
  , scrValidator
  , govValueOf
  , xgovValueOf
  , xGovMintingPolicy
  , xGovCurrencySymbol
  , Governance
  , govToken
  ) where

import Data.Coerce (coerce)
import PlutusTx.AssocMap qualified as AssocMap
import PlutusTx qualified
import PlutusTx.Prelude hiding (Semigroup(..), unless)
import Ledger hiding (singleton)
import Ledger.Typed.Scripts      qualified as Scripts
import Plutus.V1.Ledger.Value    qualified as Value
import Plutus.V1.Ledger.Contexts qualified as Contexts

govToken :: TokenName
govToken = "GOV"

-- TODO: parametrize it by an NFT
-- Validator of the governance contract
{-# INLINABLE mkValidator #-}
mkValidator :: CurrencySymbol -> AssocMap.Map PubKeyHash Integer -> () -> ScriptContext -> Bool
mkValidator cs _ _ _ = True -- todo: can't do it w/o validator type, do that one first

data Governance
instance Scripts.ScriptType Governance where
    type instance DatumType Governance = AssocMap.Map PubKeyHash Integer
    type instance RedeemerType Governance = () -- todo: needs to restructure so that Api types have a representation here
    
scrInstance :: CurrencySymbol -> Scripts.ScriptInstance Governance
scrInstance csym = Scripts.validator @Governance
  ($$(PlutusTx.compile [|| mkValidator ||]) `PlutusTx.applyCode` PlutusTx.liftCode csym)
  $$(PlutusTx.compile [|| wrap ||])
  where
    wrap = Scripts.wrapValidator @(Scripts.DatumType Governance) @(Scripts.RedeemerType Governance)

scrValidator :: CurrencySymbol -> Validator
scrValidator = Scripts.validatorScript . scrInstance

scrAddress :: CurrencySymbol -> Ledger.Address
scrAddress = scriptAddress . scrValidator

govValueOf :: CurrencySymbol -> Integer -> Value
govValueOf csym  = Value.singleton csym govToken

xgovValueOf :: CurrencySymbol -> TokenName -> Integer -> Value
xgovValueOf csym tok = Value.singleton csym tok

-- xGOV minting policy
{-# INLINABLE mkPolicy #-}
mkPolicy :: CurrencySymbol -> ScriptContext -> Bool
mkPolicy csym ctx =
  traceIfFalse "More than one signature" checkOneSignature  &&
  traceIfFalse "Incorrect tokens minted" checkxGov &&
  traceIfFalse "GOV not paid to the script" checkGovToScr
  where
    info = scriptContextTxInfo ctx

    checkOneSignature = length (txInfoSignatories info) == 1 

    checkxGov = case Value.flattenValue (Contexts.txInfoForge info) of
      [(cur, tn, amm)] -> cur == Contexts.ownCurrencySymbol ctx && amm == govPaidAmm && [coerce tn] == txInfoSignatories info -- to be tested
      _ -> False

    -- checks that the GOV was paid to the governance script, returns the value of it
    -- TODO: either fix the ByteString problems OR wait until they get patched (preferrably)
    (checkGovToScr, govPaidAmm) = case fmap txOutValue . find (\txout -> {- scrAddress csym == txOutAddress txout -} True) $ txInfoOutputs info of
      Nothing  -> (False,0) 
      Just val -> case Value.flattenValue val of
        [(cur, tn, amm)] -> (cur == csym {- && tn == govToken -}, amm)
        _ -> (False,0)
        
xGovMintingPolicy :: CurrencySymbol -> Scripts.MonetaryPolicy
xGovMintingPolicy csym = mkMonetaryPolicyScript $
  $$(PlutusTx.compile [|| Scripts.wrapMonetaryPolicy . mkPolicy ||]) `PlutusTx.applyCode` PlutusTx.liftCode csym 

-- may be a good idea to newtype these two
-- | takes in the GOV CurrencySymbol, returns the xGOV CurrencySymbol
xGovCurrencySymbol :: CurrencySymbol -> CurrencySymbol
xGovCurrencySymbol = scriptCurrencySymbol . xGovMintingPolicy 