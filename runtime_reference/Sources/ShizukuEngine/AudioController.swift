//
//  AudioController.swift
//  ShizukuEngine
//
//  Native macOS audio subsystem built on AVAudioEngine.
//  Handles:
//   - 25 Ogg Vorbis BGM tracks with seamless looping and cross-scene persistence
//   - 13 RIFF WAV SFX tracks with independent mixing
//   - BGM fade-out and stop controls
//

import Foundation
import AVFoundation

public final class AudioController {
    public let baseDir: String
    public var isEnabled: Bool = true
    public var bgmVolume: Float = 0.8 {
        didSet { bgmPlayer.volume = bgmVolume }
    }
    public var sfxVolume: Float = 1.0 {
        didSet { sfxPlayer.volume = sfxVolume }
    }

    private let engine = AVAudioEngine()
    private let bgmPlayer = AVAudioPlayerNode()
    private let sfxPlayer = AVAudioPlayerNode()

    public private(set) var currentBgm: Int? = nil
    private var isEngineRunning = false

    public init(baseDir: String) {
        self.baseDir = baseDir
        setupAudio()
    }

    private func setupAudio() {
        engine.attach(bgmPlayer)
        engine.attach(sfxPlayer)

        let mixer = engine.mainMixerNode
        engine.connect(bgmPlayer, to: mixer, format: nil)
        engine.connect(sfxPlayer, to: mixer, format: nil)

        bgmPlayer.volume = bgmVolume
        sfxPlayer.volume = sfxVolume

        startEngineIfNeeded()
    }

    private func startEngineIfNeeded() {
        guard !isEngineRunning else { return }
        do {
            try engine.start()
            isEngineRunning = true
        } catch {
            print("AudioController: failed to start AVAudioEngine: \(error)")
        }
    }

    /// Resolve BGM file URL for track number (0..23, 99).
    public func bgmURL(for track: Int) -> URL? {
        let name = String(format: "MUS%02d.OGG", track)
        let candidates = [
            baseDir + "/bgm/" + name,
            baseDir + "/" + name,
            baseDir + "/research/extracted/bgm/" + name
        ]
        for c in candidates {
            if FileManager.default.fileExists(atPath: c) {
                return URL(fileURLWithPath: c)
            }
        }
        return nil
    }

    /// Resolve SFX file URL for a given name or number (e.g. "P001", "P001.WAV", "1", "11X").
    public func sfxURL(for identifier: String) -> URL? {
        var clean = identifier.uppercased()
        if !clean.hasSuffix(".WAV") { clean += ".WAV" }
        if !clean.hasPrefix("P") { clean = "P" + clean }

        let candidates = [
            baseDir + "/sound/" + clean,
            baseDir + "/" + clean,
            baseDir + "/research/extracted/sound/" + clean
        ]
        for c in candidates {
            if FileManager.default.fileExists(atPath: c) {
                return URL(fileURLWithPath: c)
            }
        }
        return nil
    }

    private var fadeTimer: Timer?

    /// Cancel an in-flight fade-out. Mirrors `LvnsStartMusic*`, which always clears
    /// `music_fade_mode` — without this, a pending fade timer would stop the *next*
    /// track ~0.5s after it started (the "scene has no BGM" symptom).
    private func cancelFade() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        bgmFadeEndsAt = nil
        bgmPlayer.volume = bgmVolume
    }

    /// `AVAudioPlayerNode.scheduleBuffer` aborts the process with an uncaught
    /// `NSException` (`required condition is false:
    /// _outputFormat.channelCount == buffer.format.channelCount`) when the buffer's
    /// format differs from the node's output format. The 1996 assets are mono
    /// (P0xx.WAV) and mixed rate, so they must be converted before scheduling —
    /// a crash otherwise arrives from deep inside an opcode handler and unwinds the
    /// whole interpreter silently.
    static func convertedBuffer(from file: AVAudioFile, to dst: AVAudioFormat) -> AVAudioPCMBuffer? {
        let src = file.processingFormat
        guard dst.channelCount > 0 else { return nil }
        if src.channelCount == dst.channelCount, src.sampleRate == dst.sampleRate {
            guard let buffer = AVAudioPCMBuffer(pcmFormat: src,
                                                frameCapacity: AVAudioFrameCount(file.length)) else { return nil }
            guard (try? file.read(into: buffer)) != nil else { return nil }
            return buffer
        }
        guard let converter = AVAudioConverter(from: src, to: dst) else { return nil }
        guard let input = AVAudioPCMBuffer(pcmFormat: src,
                                           frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: input)) != nil else { return nil }
        let ratio = dst.sampleRate / src.sampleRate
        guard let output = AVAudioPCMBuffer(pcmFormat: dst,
                                            frameCapacity: AVAudioFrameCount(Double(input.frameLength) * ratio) + 16) else { return nil }
        var supplied = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, outStatus in
            if supplied { outStatus.pointee = .noDataNow; return nil }
            supplied = true
            outStatus.pointee = .haveData
            return input
        }
        guard status != .error, error == nil else { return nil }
        return output
    }

    private func convertedBuffer(from file: AVAudioFile, for node: AVAudioPlayerNode) -> AVAudioPCMBuffer? {
        Self.convertedBuffer(from: file, to: node.outputFormat(forBus: 0))
    }

    /// Play a BGM track with optional seamless looping.
    /// If the requested track is already playing, this is a no-op so music persists smoothly across scenes.
    public func playBGM(number: Int, loop: Bool = true) {
        guard isEnabled else { return }
        cancelFade()
        if currentBgm == number && bgmPlayer.isPlaying {
            return
        }

        guard let url = bgmURL(for: number) else {
            print("AudioController: BGM track \(number) not found")
            return
        }

        startEngineIfNeeded()

        do {
            let audioFile = try AVAudioFile(forReading: url)
            guard let buffer = convertedBuffer(from: audioFile, for: bgmPlayer) else { return }

            bgmPlayer.stop()
            let options: AVAudioPlayerNodeBufferOptions = loop ? [.loops] : []
            bgmPlayer.scheduleBuffer(buffer, at: nil, options: options, completionHandler: nil)
            bgmPlayer.play()
            currentBgm = number
        } catch {
            print("AudioController: failed to play BGM \(number): \(error)")
        }
    }

    /// Stop BGM playback.
    public func stopBGM() {
        cancelFade()
        bgmPlayer.stop()
        currentBgm = nil
    }

    /// Stop the sound-effect channel. The PCM `'Ps'` inline command maps here; it does not
    /// touch BGM, which has its own `'Ms'` command.
    public func stopAllSFX() {
        sfxPlayer.stop()
    }

    /// Fade out BGM over specified duration in seconds. The original ramps the volume to 0
    /// over 0.5s (`Lvns.c Interval()`, "0.5秒単位").
    public private(set) var bgmFadeEndsAt: Date?
    public var isBGMFading: Bool { (bgmFadeEndsAt ?? Date.distantPast) > Date() }
    public var bgmFadeRemaining: TimeInterval { max(0, (bgmFadeEndsAt ?? Date()).timeIntervalSinceNow) }

    public func fadeOutBGM(duration: TimeInterval = 0.5) {
        guard bgmPlayer.isPlaying else { return }
        fadeTimer?.invalidate()
        let steps = 20
        let stepTime = duration / Double(steps)
        let initialVol = bgmPlayer.volume
        var currentStep = 0
        bgmFadeEndsAt = Date().addingTimeInterval(duration)

        let timer = Timer(timeInterval: stepTime, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            currentStep += 1
            let ratio = Float(steps - currentStep) / Float(steps)
            self.bgmPlayer.volume = max(0, initialVol * ratio)
            if currentStep >= steps {
                timer.invalidate()
                self.fadeTimer = nil
                // Original: ramp reaching 0 fires LvnsPauseMusic (current_music = 0).
                self.stopBGM()
            }
        }
        // `.common`, not the `.default` mode `scheduledTimer` picks up: the ramp would
        // otherwise freeze for as long as a mouse button is held or a menu is open.
        RunLoop.main.add(timer, forMode: .common)
        fadeTimer = timer
    }

    /// Play sound effect by name or code (e.g. "P001", "P011X").
    public func playSFX(name: String) {
        guard isEnabled else { return }
        guard let url = sfxURL(for: name) else {
            return
        }

        startEngineIfNeeded()

        do {
            let audioFile = try AVAudioFile(forReading: url)
            guard let buffer = convertedBuffer(from: audioFile, for: sfxPlayer) else { return }

            sfxPlayer.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
            if !sfxPlayer.isPlaying {
                sfxPlayer.play()
            }
        } catch {
            print("AudioController: failed to play SFX \(name): \(error)")
        }
    }
}
