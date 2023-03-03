module Database.Redis.Streams.Types.ConsumerGroup where

import Data.ByteString
import Database.Redis.Streams.Types.Stream
import GHC.Generics

newtype ConsumerGroupName = ConsumerGroupName {unConsumerGroupName :: ByteString}
    deriving (Show, Eq, Generic, Ord)

data ConsumerGroup = ConsumerGroup {name :: ConsumerGroupName, streamKey :: StreamKey}
    deriving (Show, Eq, Generic, Ord)

newtype ConsumerName = ConsumerName {unConsumerName :: ByteString}
    deriving (Show, Eq, Generic, Ord)

data Consumer = Consumer {name :: ConsumerName, group :: ConsumerGroup}
    deriving (Show, Eq, Generic, Ord)

newtype AutoclaimConsumer = AutoclaimConsumer {getConsumer :: Consumer}
    deriving (Show, Eq, Generic, Ord)
