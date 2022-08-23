{-# LANGUAGE PartialTypeSignatures #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Database.Redis.Streams.ConsumerGroup where

import Control.Exception
import Control.Monad.Except
import Data.ByteString
import Data.ByteString qualified as BS
import Data.ByteString.Char8 qualified as BS8
import Data.Coerce
import Database.Redis (MonadRedis, Redis, RedisCtx, Reply (..), Status, StreamsRecord, TxResult (..), XReadOpts)
import Database.Redis qualified as Redis
import Database.Redis.Streams.Extras qualified as RedisEx
import Database.Redis.Streams.SpecialMessageID
import Database.Redis.Streams.Types
import Optics.Core
import Optics.Generic ()

{- | Get existing consumer group or create a new one.

New consumer group will see only new messages.
-}
getOrCreateConsumerGroup :: StreamKey -> ConsumerGroupName -> Redis (Either RedisStreamSomeError ConsumerGroup)
getOrCreateConsumerGroup key name = do
    res :: Either Reply Status <-
        Redis.sendRequest ["XGROUP", "CREATE", coerce key, coerce name, coerce newestMessageID, "MKSTREAM"]
    case res of
        Left (Error bs) | "BUSYGROUP" `BS.isInfixOf` bs -> pure $ Right ConsumerGroup{streamKey = key, name = name}
        Left err -> pure $ Left $ replyToRedisStreamSomeError err
        Right sta -> pure $ Right ConsumerGroup{streamKey = key, name = name}

deleteConsumer :: Consumer -> Redis (Either RedisStreamSomeError ())
deleteConsumer consumer = runExceptT . withExceptT replyToRedisStreamSomeError $ do
    ExceptT $
        Redis.xgroupDelConsumer
            (consumer ^. #group % #streamKey & coerce)
            (consumer ^. #group % #name & coerce)
            (consumer ^. #name & coerce)
    pure ()

{- | Consume messages from stream by 'Redis.xack' followed by 'Redis.xdel' in one round-trip time.

This or 'ackMessages' should be used after processing messages.

 Removes messages from original stream.
 Use 'ackMessages' for version that leaves messages in stream.
-}
consumeMessages :: ConsumerGroup -> [MessageID] -> Redis (Either RedisStreamSomeError ())
consumeMessages group messages = do
    let key = coerce $ group ^. #streamKey
    res <- Redis.multiExec $ do
        Redis.xack key (group ^. #name & coerce) (coerce messages)
        Redis.xdel key (coerce messages)
    pure $ case res of
        TxSuccess _ -> Right ()
        err@TxAborted -> Left . RedisStreamError . BS8.pack $ show err
        err@(TxError s) -> Left . RedisStreamError . BS8.pack $ show err

{- | Consume messages from stream by 'Redis.xack'.

  This or 'consumeMessages' should be used after processing messages.

  Leaves original message in redis stream, possible leak when used for a long time.
  Use 'consumeMessages' for version that removes messages from stream.
-}
ackMessages :: ConsumerGroup -> [MessageID] -> Redis (Either RedisStreamSomeError ())
ackMessages group messages = runExceptT . withExceptT replyToRedisStreamSomeError $ do
    let key = coerce $ group ^. #streamKey
    ExceptT $ Redis.xack key (group ^. #name & coerce) (coerce messages)
    return ()

{- | Read next messages as consumer in consumer group.
 Producer for your favorite streaming library.
-}
readStreamAsConsumer :: Consumer -> XReadOpts -> Redis (Either RedisStreamSomeError [StreamsRecord])
readStreamAsConsumer consumer readOpts = do
    res <-
        Redis.xreadGroupOpts @Redis
            (consumer ^. #group % #name & coerce)
            (consumer ^. #name & coerce)
            [(consumer ^. #group % #streamKey & coerce, coerce nextNotDeliveredMessageID)]
            readOpts
    pure $ case res of
        (Left err) -> Left $ replyToRedisStreamSomeError err
        -- Will be one response as only one stream is read
        Right (Just responses) -> Right $ do
            response <- responses
            Redis.records response
        Right Nothing -> Right []

{- | Read unclaimed messaged is PEL as consumer in consumer group.

 Will

 Producer for your favorite streaming library.
-}
readPendingMessages :: Consumer -> MessageID -> XAutoclaimOpts -> Redis (Either RedisStreamSomeError (Maybe MessageID, [StreamsRecord]))
readPendingMessages consumer lstMsgId autoclaimOpts = do
    res <-
        RedisEx.xautoclaimOpts
            (consumer ^. #group % #streamKey & coerce)
            (consumer ^. #group % #name & coerce)
            (consumer ^. #name & coerce)
            (coerce lstMsgId)
            autoclaimOpts
    pure $ case res of
        Left err -> Left $ replyToRedisStreamSomeError err
        Right XAutoclaimResponse{nextStreamId, records}
            | nextStreamId == coerce autoclaimNewScanMessageID ->
                Right (Nothing, records)
            | otherwise ->
                Right (Just $ MessageID nextStreamId, records)