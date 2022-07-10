module Database.Redis.Streams.Types.Stream where

import Data.ByteString
import GHC.Generics

newtype MessageID = MessageID {messageID :: ByteString}
    deriving (Show, Eq, Generic, Ord)

newtype StreamKey = StreamKey {streamKey :: ByteString}
    deriving (Show, Eq, Generic, Ord)

newtype EntryField = EntryField {entryField :: ByteString}
    deriving (Show, Eq, Generic, Ord)

newtype EntryValue = EntryValue {entryValue :: ByteString}
    deriving (Show, Eq, Generic, Ord)

newtype Entry = Entry {entry :: [(EntryField, EntryValue)]}
    deriving (Show, Eq, Generic, Ord)