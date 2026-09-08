// Play Asset Delivery pack with the paid-pack illustrations and voice clips.
//
// src/main/assets is a symlink to ../../assets/pad_content, so the files are
// authored once (tools/pad_split.py moves them there) and this module just
// wraps them. fast-follow: Play downloads the pack right after install, in
// the background, without the app asking; the base module stays small enough
// for the first session on a slow connection. AssetPackService (Dart) reads
// the pack through AssetPackManager.getPackLocation().assetsPath(), where the
// paths mirror pad_content: images/webp/<name>.webp, audio_mp3/<name>.mp3.
plugins {
    id("com.android.asset-pack")
}

assetPack {
    packName.set("content_pack")
    dynamicDelivery {
        deliveryType.set("fast-follow")
    }
}
