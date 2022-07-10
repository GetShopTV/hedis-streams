module Database.Redis.Streams.Extras where

import Data.ByteString hiding (concat)
import Data.ByteString qualified as BS hiding (concat)
import Data.ByteString.Char8 qualified as BS8
import Data.Maybe
import Database.Redis
import Database.Redis qualified as Redis
import Database.Redis.Streams.Types.Extras

xautoclaimOpts ::
  ByteString ->
  ByteString ->
  ByteString ->
  ByteString ->
  XAutoclaimOpts ->
  Redis (Either Reply XAutoclaimResponse)
xautoclaimOpts key group consumer startMsgId XAutoclaimOpts{..} =
  Redis.sendRequest $ ["XAUTOCLAIM", key, group, consumer, minIdleTimeEncoded, startMsgId] ++ countEncoded
 where
  encodeBS = BS8.pack . show
  minIdleTimeEncoded = encodeBS minIdleTime
  countEncoded = maybe [] (\count' -> ["COUNT", encodeBS count']) count