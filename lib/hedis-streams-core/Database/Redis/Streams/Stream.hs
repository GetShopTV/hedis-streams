module Database.Redis.Streams.Stream where

import Control.Monad.Except
import Control.Monad.State
import Data.ByteString (ByteString)
import Data.Coerce
import Database.Redis (Redis, StreamsRecord (..), TrimOpts, XReadOpts)
import Database.Redis qualified as Redis
import Database.Redis.Streams.SpecialMessageID
import Database.Redis.Streams.Types

sendUpstream ::
    StreamKey ->
    TrimOpts ->
    Entry ->
    Redis (Either RedisStreamSomeError ByteString)
sendUpstream key trimOpts entries =
    runExceptT
        . withExceptT replyToRedisStreamSomeError
        . ExceptT
        $ Redis.xaddOpts (coerce key) (coerce autogenMessageID) (coerce entries) trimOpts

{- | Read next message from stream.

 Producer for your favorite streaming library. Use returned 'MessageID' for next iterations.
-}
readStream ::
    StreamKey -> MessageID -> XReadOpts -> Redis (Either RedisStreamSomeError (MessageID, [StreamsRecord]))
readStream key lstMsgId readOpts = do
    res <-
        Redis.xreadOpts @Redis
            [(coerce key, coerce lstMsgId)]
            readOpts
    pure $ case res of
        (Left err) -> Left $ replyToRedisStreamSomeError err
        -- Will be one response as only one stream is read
        Right (Just responses) ->
            let (records, newLstMsgId) =
                    (`runState` lstMsgId)
                        . traverse (\record -> record <$ put (MessageID $ Redis.recordId record))
                        $ Redis.records =<< responses
             in Right (newLstMsgId, records)
        Right Nothing -> Right (lstMsgId, [])