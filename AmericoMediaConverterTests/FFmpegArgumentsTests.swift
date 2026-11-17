import Testing
@testable import Americo_s_Media_Converter

struct FFmpegArgumentsTests {

    // MARK: - Audio
    @Test func wav24BitUsesS32SampleFormat() {
        let arguments = FFmpegArguments.audio(type: .WAV, bits: "24", sampleRate: "48000", aacCodec: "aac")
        #expect(arguments == "-y -sample_fmt s32 -c:a pcm_s24le -ar 48000")
    }

    @Test func wav16Bit() {
        let arguments = FFmpegArguments.audio(type: .WAV, bits: "16", sampleRate: "44100", aacCodec: "aac")
        #expect(arguments == "-y -sample_fmt s16 -c:a pcm_s16le -ar 44100")
    }

    @Test func aacDoublesBufferSize() {
        let arguments = FFmpegArguments.audio(type: .AAC, bits: "320", sampleRate: "48000", aacCodec: "libfdk_aac")
        #expect(arguments == "-y -vn -c:a libfdk_aac -b:a 320k -maxrate 320k -bufsize 640k -ar 48000")
    }

    @Test func mp3() {
        let arguments = FFmpegArguments.audio(type: .MP3, bits: "192", sampleRate: "44100", aacCodec: "aac")
        #expect(arguments == "-y -codec:a libmp3lame -b:a 192k -ar 44100")
    }


    // MARK: - Video
    @Test func proResHQDefaults() {
        let arguments = FFmpegArguments.video(codec: .ProRes, profileTitle: "HQ", resolution: .hd1080,
                                              frameRate: .auto, pad: false, hasLibx264: true, aacCodec: "aac")
        #expect(arguments == "-y -c:v prores_ks -profile:v 3 -qscale:v 9 -vendor apl0 -pix_fmt yuv422p10le -vf scale=1920:1080:force_original_aspect_ratio=decrease -c:a pcm_s24le")
    }

    @Test func proRes4444WithPadAndNTSCRate() {
        let arguments = FFmpegArguments.video(codec: .ProRes, profileTitle: "4444", resolution: .hd1080,
                                              frameRate: .fps29_97, pad: true, hasLibx264: true, aacCodec: "aac")
        #expect(arguments == "-y -c:v prores_ks -profile:v 4 -qscale:v 9 -vendor apl0 -pix_fmt yuva444p10le -vf scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,fps=30000/1001 -c:a pcm_s24le")
    }

    @Test func h264WithLibx264() {
        let arguments = FFmpegArguments.video(codec: .H264, profileTitle: "High", resolution: .hd1080,
                                              frameRate: .fps25, pad: false, hasLibx264: true, aacCodec: "aac")
        #expect(arguments == "-y -c:v libx264 -profile:v high422 -preset slow -crf 18 -vf format=yuv422p,scale=1920:1080:force_original_aspect_ratio=decrease,fps=25.0 -c:a aac -b:a 320k")
    }

    @Test func h264WithoutLibx264() {
        let arguments = FFmpegArguments.video(codec: .H264, profileTitle: "Main", resolution: .hd720,
                                              frameRate: .auto, pad: false, hasLibx264: false, aacCodec: "aac")
        #expect(arguments == "-y -c:v h264 -vf format=yuv422p,scale=1280:720:force_original_aspect_ratio=decrease -c:a aac -b:a 320k")
    }

    @Test func dnxhr10BitFilmRate() {
        let arguments = FFmpegArguments.video(codec: .DNxHD, profileTitle: "HQ 10 bits", resolution: .uhd4K,
                                              frameRate: .fps23_976, pad: false, hasLibx264: true, aacCodec: "aac")
        #expect(arguments == "-y -c:v dnxhd -profile:v dnxhr_hqx -pix_fmt yuv422p10le -vf scale=3840:2160:force_original_aspect_ratio=decrease,fps=24000/1001  -c:a pcm_s24le")
    }
}
