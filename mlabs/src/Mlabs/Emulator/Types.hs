{-# OPTIONS_GHC -fno-specialize #-}
{-# OPTIONS_GHC -fno-strictness #-}
{-# OPTIONS_GHC -fno-specialize #-}
{-# OPTIONS_GHC -fno-strictness #-}
{-# OPTIONS_GHC -fobject-code #-}
{-# OPTIONS_GHC -fno-ignore-interface-pragmas #-}
{-# OPTIONS_GHC -fno-omit-interface-pragmas #-}
module Mlabs.Emulator.Types(
    UserId(..)
  , Coin
  , adaCoin
) where

import Data.Aeson (FromJSON, ToJSON)
import qualified Prelude as Hask
import PlutusTx.Prelude

import GHC.Generics
import qualified Plutus.V1.Ledger.Ada as Ada
import Plutus.V1.Ledger.Value (AssetClass(..))
import Plutus.V1.Ledger.Crypto (PubKeyHash(..))
import qualified PlutusTx as PlutusTx

-- | Address of the wallet that can hold values of assets
data UserId
  = UserId PubKeyHash  -- user address
  | Self               -- addres of the lending platform
  deriving stock (Show, Generic, Hask.Eq, Hask.Ord)
  deriving anyclass (FromJSON, ToJSON)

instance Eq UserId where
  {-# INLINABLE (==) #-}
  Self == Self = True
  UserId a == UserId b = a == b
  _ == _ = False

{-# INLINABLE adaCoin #-}
adaCoin :: Coin
adaCoin = AssetClass (Ada.adaSymbol, Ada.adaToken)

-- | Custom currency
type Coin = AssetClass

PlutusTx.unstableMakeIsData ''UserId