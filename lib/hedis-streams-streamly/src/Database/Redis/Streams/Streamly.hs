{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE StandaloneKindSignatures #-}
{-# LANGUAGE TypeFamilies #-}

module Database.Redis.Streams.Streamly where

import Database.Redis

import Database.Redis.Internal.Instances ()
import Database.Redis.Streams.Stream
import Database.Redis.Streams.Types

import Control.Monad.Catch

import Data.Kind
import Database.Redis.Internal.Streams.ConsumerGroup.Streamly
import Database.Redis.Internal.Streams.ConsumerGroup.Streamly qualified as Consumer
import Database.Redis.Internal.Streams.Streamly
import Streamly.Data.Stream.Prelude as Stream

data RedisStreamReadMode = StreamKeyMode | ConsumerMode | ClaimMode

type RedisStreamRead :: RedisStreamReadMode -> Constraint
class RedisStreamRead mode where
    type ReadUsing mode :: Type
    type ReadOptions mode :: Type
    fromStream :: ReadUsing mode -> ReadOptions mode -> Stream Redis StreamsRecord

instance RedisStreamRead StreamKeyMode where
    type ReadUsing StreamKeyMode = StreamKey
    type ReadOptions StreamKeyMode = StreamKeyReadOptions
    fromStream key opts = fromStreamStartingFrom key (xReadOpts opts) (startingMsgID opts)

instance RedisStreamRead ConsumerMode where
    type ReadUsing ConsumerMode = Consumer
    type ReadOptions ConsumerMode = XReadOpts
    fromStream = Consumer.fromStreamAsConsumer

instance RedisStreamRead ClaimMode where
    type ReadUsing ClaimMode = Consumer
    type ReadOptions ClaimMode = ClaimReadOptions
    fromStream consumer opts = Consumer.fromPendingMessagesWithDelay consumer (xAutoclaimOpts opts) opts.delay

streamSink ::
    StreamKey ->
    TrimOpts ->
    Stream Redis Entry ->
    Stream Redis MessageID
streamSink streamOut trimOpts = Stream.mapM sendStep
  where
    sendStep entry =
        sendUpstream streamOut trimOpts entry >>= \case
            Left err -> throwM err -- Possible only when redis sends error message back
            Right msgId -> pure $ MessageID msgId