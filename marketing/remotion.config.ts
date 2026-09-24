import { Config } from '@remotion/cli/config';

// App Store / Play Store video encoding preset.
// 1080×1920 portrait, 30fps, 15 seconds — matches App Store Preview specs.
Config.setVideoImageFormat('jpeg');
Config.setPixelFormat('yuv420p');
Config.setCodec('h264');
Config.setCrf(18); // high quality; App Store rejects obvious compression artifacts.
