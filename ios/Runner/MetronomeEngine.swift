import AVFoundation
import Flutter

@objc class MetronomeEngine: NSObject {

    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var clickBuffer: AVAudioPCMBuffer?
    private var subClickBuffer: AVAudioPCMBuffer?
    private var sampleRate: Double = 44100
    private var bpm: Double = 120
    private var subdivision: Int = 1
    private var isPlaying: Bool = false
    private var nextBeatSample: AVAudioFramePosition = 0
    private var currentSubdivision: Int = 0

    static var channel: FlutterMethodChannel?

    override init() {
        super.init()
        setupAudio()
    }

    private func setupAudio() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("MetronomeEngine: audio session error: \(error)")
        }

        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }

        playerNode = AVAudioPlayerNode()
        guard let player = playerNode else { return }

        engine.attach(player)

        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        sampleRate = format.sampleRate

        engine.connect(player, to: engine.mainMixerNode, format: format)

        clickBuffer = makeClickBuffer(format: format, frequency: 1800, volume: 0.9)
        subClickBuffer = makeClickBuffer(format: format, frequency: 1200, volume: 0.45)

        do {
            try engine.start()
        } catch {
            print("MetronomeEngine: engine start error: \(error)")
        }
    }

    private func makeClickBuffer(format: AVAudioFormat,
                                  frequency: Double,
                                  volume: Float) -> AVAudioPCMBuffer? {
        let clickDuration: Double = 0.012
        let frameCount = AVAudioFrameCount(sampleRate * clickDuration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount

        let channelCount = Int(format.channelCount)
        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let envelope = exp(-t / 0.007)
            let sample = Float(sin(2.0 * .pi * frequency * t) * envelope) * volume
            for ch in 0..<channelCount {
                buffer.floatChannelData?[ch][frame] = sample
            }
        }
        return buffer
    }

    @objc func start(bpm: Double, subdivision: Int) {
        stop()
        self.bpm = bpm
        self.subdivision = max(1, subdivision)
        isPlaying = true
        currentSubdivision = 0

        guard let player = playerNode,
              let engine = audioEngine,
              let click = clickBuffer,
              let subClick = subClickBuffer else { return }

        if !engine.isRunning {
            try? engine.start()
        }

        player.play()

        let samplesPerBeat = sampleRate * 60.0 / bpm
        let samplesPerSub = AVAudioFramePosition(samplesPerBeat / Double(self.subdivision))

        nextBeatSample = player.lastRenderTime.map {
            player.playerTime(forNodeTime: $0)?.sampleTime ?? 0
        } ?? 0

        scheduleSubdivision(click: click, subClick: subClick,
                             samplesPerSub: samplesPerSub)
    }

    private func scheduleSubdivision(click: AVAudioPCMBuffer,
                                      subClick: AVAudioPCMBuffer,
                                      samplesPerSub: AVAudioFramePosition) {
        guard isPlaying, let player = playerNode else { return }

        let isMainBeat = (currentSubdivision % subdivision == 0)
        let buffer = isMainBeat ? click : subClick

        let time = AVAudioTime(sampleTime: nextBeatSample, atRate: sampleRate)
        nextBeatSample += samplesPerSub
        currentSubdivision += 1

        player.scheduleBuffer(buffer, at: time, options: []) { [weak self] in
            guard let self = self, self.isPlaying else { return }

            if isMainBeat {
                DispatchQueue.main.async {
                    MetronomeEngine.channel?.invokeMethod("onBeat", arguments: nil)
                }
            }

            self.scheduleSubdivision(click: click, subClick: subClick,
                                      samplesPerSub: samplesPerSub)
        }
    }

    @objc func stop() {
        isPlaying = false
        currentSubdivision = 0
        playerNode?.stop()
        playerNode?.reset()
    }

    @objc func updateBpm(_ newBpm: Double) {
        if isPlaying {
            start(bpm: newBpm, subdivision: subdivision)
        } else {
            self.bpm = newBpm
        }
    }

    @objc func updateSubdivision(_ newSubdivision: Int) {
        if isPlaying {
            start(bpm: bpm, subdivision: newSubdivision)
        } else {
            self.subdivision = max(1, newSubdivision)
        }
    }
}