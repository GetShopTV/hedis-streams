module Database.Redis.Streams.Common where

import Codec.Winery qualified as Winery
import Data.ByteString.Builder qualified as BSB
import Data.ByteString.Lazy qualified as BSL
import Data.Store
import Data.Typeable
import Database.Redis hiding (decode)
import Database.Redis.Streams.Types
import Streamly.Data.Unfold qualified as Unfold
import Streamly.Prelude qualified as Streamly

{- | Placeholder entry field to store serialized data.
 If possible use your type version as key.
-}
storePlaceholderStreamEntryField :: EntryField
storePlaceholderStreamEntryField = EntryField "noversion"

toStoreEntryWithField :: Store a => EntryField -> a -> Entry
toStoreEntryWithField field x = Entry [(field, EntryValue $ encode x)]

storeStreamConsumerGroupName :: ConsumerGroupName
storeStreamConsumerGroupName = ConsumerGroupName "dstore_default_cg"

-- | Create stream key from type name and schema representation.
streamKeyFromData :: (Winery.Serialise a) => proxy a -> StreamKey
streamKeyFromData proxy = StreamKey . BSL.toStrict . BSB.toLazyByteString $ typeName <> BSB.charUtf8 '_' <> schema
  where
    typeName = BSB.stringUtf8 . show . typeRep $ proxy
    schema = BSB.byteString $ Winery.serialiseSchema . Winery.schema $ proxy

deserializedStreamsRecordUnfold ::
    Store a => Unfold.Unfold Redis StreamsRecord (MessageID, EntryField, Either PeekException a)
deserializedStreamsRecordUnfold =
    Unfold.many
        -- Extract stream entries
        -- There always should be one key/value pair in store stream entry
        -- Pair entry with it's message id, decode the value
        ( Unfold.function
            ( \StreamsRecord{recordId, keyValues} ->
                -- Key should be "version" of your datatype.
                -- Allows multiple serialized types in the same message
                fmap (\(versionKey, value) -> (MessageID recordId, EntryField versionKey, decode value)) keyValues
            )
        ) -- Flatten
        Unfold.fromList