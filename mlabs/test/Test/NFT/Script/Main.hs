module Test.NFT.Script.Main where

import Test.NFT.Script.Dealing
import Test.NFT.Script.Minting
import Test.NFT.Script.Auction
import Test.Tasty (TestTree, testGroup)

test :: TestTree
test =
  testGroup
    "NFT rewrite script tests"
    [ testMinting
    , testDealing
    , testAuctionBeforeDeadline
    , testAuctionAfterDeadline
    ]
