module Database.Redis.Streams.Types.Error where

import Control.Exception
import Data.ByteString
import Database.Redis

data RedisStreamSomeError = RedisStreamError ByteString | RedisStreamWrongResponse String
    deriving (Show)
    deriving anyclass (Exception)

replyToRedisStreamSomeError :: Reply -> RedisStreamSomeError
replyToRedisStreamSomeError reply = case reply of
    (Error bs) -> RedisStreamError bs
    err -> RedisStreamWrongResponse (show err)
