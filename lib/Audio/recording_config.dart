import 'package:audio_waveforms/audio_waveforms.dart';

/// Every recording this app makes — takes and voice answers alike — is 16-bit
/// mono PCM WAV at 44.1 kHz.
///
/// It is not a quality preference. `WavAnalyzer` reads a canonical WAV header
/// at fixed offsets and checks against exactly these values, `WavMerger` can
/// only concatenate sources that share a format, and the server refuses
/// anything that is not PCM. Recording in one place with different settings
/// would break all three at once.
const RecorderSettings kObtRecorderSettings = RecorderSettings(
  androidEncoderSettings: AndroidEncoderSettings(
    androidEncoder: AndroidEncoder.wav,
  ),
  iosEncoderSettings: IosEncoderSetting(
    iosEncoder: IosEncoder.kAudioFormatLinearPCM,
    linearPCMBitDepth: 16,
    linearPCMIsBigEndian: false,
    linearPCMIsFloat: false,
  ),
  sampleRate: 44100,
);
