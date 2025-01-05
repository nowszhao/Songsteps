import Foundation
import AVFoundation
import Accelerate
import Speech

// 添加支持的语言枚举
enum RecognitionLanguage: String, CaseIterable {
    case english = "en-US"
    case chinese = "zh-CN"
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .chinese: return "中文"
        }
    }
}

class AudioManager: NSObject, ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var audioPlayer: AVAudioPlayer?
    private var playerNode: AVAudioPlayerNode?
    private var timer: Timer?
    private var bufferSize: AVAudioFrameCount = 1024
    
    @Published var currentTime: Double = 0
    @Published var audioData: [Float] = Array(repeating: 0, count: 80)
    @Published var lyricWaveform: [Float] = Array(repeating: 0, count: 80)
    @Published var isPlaying: Bool = false
    
    var lastLyricText: String = ""
    
    private var audioFile: AVAudioFile?
    private var audioBuffer: AVAudioPCMBuffer?
    private var cachedWaveforms: [String: [Float]] = [:] // 缓存每句歌词对应的波形
    
    @Published var recordedWaveform: [Float] = Array(repeating: 0, count: 80)
    @Published var isRecording: Bool = false
    @Published var recognizedText: String = ""
    
    private var speechRecognizer: SFSpeechRecognizer?
    @Published var currentLanguage: RecognitionLanguage = .english
    
    private var recordingSession: AVAudioSession?
    private var audioRecorder: AVAudioRecorder?
    private var recordedFileURL: URL?
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private var recordedAudioPlayer: AVAudioPlayer?
    @Published var isPlayingRecording: Bool = false
    
    @Published var isLoopEnabled: Bool = false
    private var loopStartTime: Double = 0
    private var loopEndTime: Double = 0
    
    private let scoreService = SingingScoreService()
    @Published var lastScore: SingingScore?
    
    @Published var currentMatchResult: LyricMatchResult?
    
    private var lastRecognitionResult: String = ""
    
    private let recordingManager = LyricRecordingManager.shared
    private var currentLyricId: String?
    
    private var timePitch: AVAudioUnitTimePitch?
    @Published var playbackRate: Float = 1.0
    
    var duration: Double {
        audioPlayer?.duration ?? 0
    }
    
    override init() {
        super.init()
        setupRecording()
        setupSpeechRecognizer()
    }
    
    func setupAudio(url: URL) {
        do {
            // 停止之前的引擎和播放器
            stop()
            audioEngine?.stop()
            audioEngine = nil
            
            // 重新设置音频会话
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, 
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth])
            try AVAudioSession.sharedInstance().setActive(true)
            
            // 只使用 AVAudioFile 来读取音频数据
            audioFile = try AVAudioFile(forReading: url)
            
            // 加载整个音频文件并生成波形
            if let audioFile = audioFile {
                let frameCount = UInt32(audioFile.length)
                audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: frameCount)
                try audioFile.read(into: audioBuffer!)
                
                // 生成整个音频的波形
                if let buffer = audioBuffer,
                   let channelData = buffer.floatChannelData?[0] {
                    let samples = Array(UnsafeBufferPointer(start: channelData, 
                                                          count: Int(buffer.frameLength)))
                    audioData = generateStaticWaveform(from: samples)
                }
            }
            
            setupEngine(with: url)
        } catch {
            print("Error setting up audio: \(error)")
        }
    }
    
    private func setupEngine(with url: URL) {
        audioEngine?.stop()
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        timePitch = AVAudioUnitTimePitch()
        
        guard let engine = audioEngine,
              let player = playerNode,
              let pitch = timePitch else { return }
        
        do {
            let audioFile = try AVAudioFile(forReading: url)
            
            engine.attach(player)
            engine.attach(pitch)
            
            // 连接节点: player -> timePitch -> mainMixer
            engine.connect(player, to: pitch, format: audioFile.processingFormat)
            engine.connect(pitch, to: engine.mainMixerNode, format: audioFile.processingFormat)
            
            try engine.start()
            player.scheduleFile(audioFile, at: nil)
        } catch {
            print("Error setting up audio engine: \(error)")
        }
    }
    
    func play(fromTime: Double? = nil) {
        guard let engine = audioEngine,
              let player = playerNode,
              let audioFile = self.audioFile else {
            return
        }
        
        // 如果引擎没有运行，重新启动它
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                print("Error starting audio engine: \(error)")
                return
            }
        }
        
        // 停止当前播放
        player.stop()
        
        if let time = fromTime {
            print("从指定时间开始播放: \(time)")
            // 计算开始位置
            let sampleRate = audioFile.processingFormat.sampleRate
            let sampleTime = AVAudioFramePosition(time * sampleRate)
            let frameCount = AVAudioFrameCount(audioFile.length - AVAudioFramePosition(sampleTime))
            
            // 从指定位置调度音频
            player.scheduleSegment(
                audioFile,
                startingFrame: sampleTime,
                frameCount: frameCount,
                at: nil
            )
            currentTime = time
        } else {
            print("从头开始播放")
            // 从头开始播放
            player.scheduleFile(audioFile, at: nil)
            currentTime = 0
        }
        
        player.play()
        isPlaying = true
        startMonitoring()
    }
    
    func pause() {
        playerNode?.pause()
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }
    
    func stop() {
        playerNode?.stop()
        isPlaying = false
        currentTime = 0
        timer?.invalidate()
        timer = nil
        audioData = Array(repeating: 0, count: 80)
    }
    
    private func startMonitoring() {
        print("开始监控播放时间")
        timer?.invalidate()
        timer = nil
        
        guard let engine = audioEngine,
              let player = playerNode,
              let audioFile = self.audioFile,
              engine.isRunning else {
            print("监控启动失败 - 组件未就绪")
            return
        }
        
        // 记录开始监控时的时间点
        let startTime = currentTime
        let startSampleTime = AVAudioFramePosition(startTime * audioFile.processingFormat.sampleRate)
        print("开始监控 - 初始时间: \(startTime), 采样点: \(startSampleTime)")
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self,
                  let lastRenderTime = player.lastRenderTime,
                  let playerTime = player.playerTime(forNodeTime: lastRenderTime) else {
                return
            }
            
            let sampleRate = audioFile.processingFormat.sampleRate
            // 计算相对于起始位置的偏移时间
            let elapsedSamples = Double(playerTime.sampleTime)
            let newTime = startTime + (elapsedSamples / sampleRate)
            self.currentTime = newTime
            
            // 检查循环播放
            if self.isLoopEnabled && newTime >= self.loopEndTime {
                print("循环播放 - 返回到开始时间: \(self.loopStartTime)")
                
                // 停止当前播放
                player.stop()
                
                // 计算新的开始位置
                let loopStartSample = AVAudioFramePosition(self.loopStartTime * sampleRate)
                let frameCount = AVAudioFrameCount(audioFile.length - loopStartSample)
                
                // 从循环起始位置重新调度
                player.scheduleSegment(
                    audioFile,
                    startingFrame: loopStartSample,
                    frameCount: frameCount,
                    at: nil,
                    completionHandler: nil
                )
                
                // 更新当前时间并重新开始播放
                self.currentTime = self.loopStartTime
                player.play()
                
                // 重新开始监控
                self.startMonitoring()
            }
        }
    }
    
    func onLyricChanged(lyricId: String, text: String, startTime: Double, endTime: Double) {
        lastLyricText = text
        currentLyricId = lyricId
        
        // 检查是否有已存在的录音记录
        if let recording = recordingManager.getRecording(for: lyricId) {
            lastScore = recording.score
            currentMatchResult = recording.matchResult
            recognizedText = recording.recognizedText
            
            // 加载已存在的录音波形
            if let recordingURL = try? recordingManager.getRecordingURL(for: recording) {
                generateRecordedWaveform(from: recordingURL)
            }
        } else {
            // 清除之前的录音相关数据
            lastScore = nil
            currentMatchResult = nil
            recognizedText = ""
            recordedWaveform = Array(repeating: 0, count: 80)
        }
        
        // 检查是否已缓存
        if let cachedWaveform = cachedWaveforms[text] {
            lyricWaveform = cachedWaveform
            return
        }
        
        // 从音频buffer中提取对应时间段的数据
        if let buffer = audioBuffer,
           let channelData = buffer.floatChannelData?[0] {
            let sampleRate = Float(buffer.format.sampleRate)
            let startSample = Int(startTime * Double(sampleRate))
            let endSample = Int(min(endTime * Double(sampleRate), Double(buffer.frameLength)))
            
            let samples = Array(UnsafeBufferPointer(start: channelData.advanced(by: startSample),
                                                   count: endSample - startSample))
            
            // 生成静态波形
            let waveform = generateStaticWaveform(from: samples)
            
            // 缓存波形数据
            cachedWaveforms[text] = waveform
            lyricWaveform = waveform
        }
    }
    
    private func generateStaticWaveform(from samples: [Float]) -> [Float] {
        let segmentCount = 40
        let samplesPerSegment = samples.count / segmentCount
        var processedData: [Float] = []
        
        // 计算每个段的RMS值
        for i in 0..<segmentCount {
            let startIndex = i * samplesPerSegment
            let endIndex = min(startIndex + samplesPerSegment, samples.count)
            let segment = samples[startIndex..<endIndex]
            let rms = sqrt(segment.map { $0 * $0 }.reduce(0, +) / Float(segment.count))
            processedData.append(rms)
        }
        
        // 归一化
        if let maxValue = processedData.max(), maxValue > 0 {
            processedData = processedData.map { min($0 / maxValue, 1.0) }
        }
        
        // 创建对称波形
        var symmetricData: [Float] = Array(repeating: 0, count: 80)
        for i in 0..<40 {
            let value = processedData[i]
            symmetricData[i * 2] = value
            symmetricData[i * 2 + 1] = -value
        }
        
        return symmetricData
    }
    
    private func processAudioData(_ buffer: AVAudioPCMBuffer) {
        let channelData = buffer.floatChannelData?[0]
        let frameCount = UInt32(buffer.frameLength)
        
        if let data = channelData {
            var rms: Float = 0.0
            vDSP_measqv(data, 1, &rms, UInt(frameCount))
            rms = sqrt(rms)
            
            // 更新实时音频数据
            DispatchQueue.main.async {
                self.audioData = self.generateStaticWaveform(from: Array(UnsafeBufferPointer(start: data, count: Int(frameCount))))
            }
        }
    }
    
    func setupRecording() {
        recordingSession = AVAudioSession.sharedInstance()
        do {
            // 修改音频会话配置
            try recordingSession?.setCategory(.playAndRecord, 
                                            mode: .default,
                                            options: [.defaultToSpeaker, .allowBluetooth])
            try recordingSession?.setActive(true, options: .notifyOthersOnDeactivation)
            
            // 请求录音权限
            recordingSession?.requestRecordPermission() { [weak self] allowed in
                DispatchQueue.main.async {
                    if !allowed {
                        print("录音权限被拒绝")
                    }
                }
            }
        } catch {
            print("录音设置失败: \(error)")
        }
    }
    
    func startRecording(startTime: Double, endTime: Double) {
        // 确保先停止之前的录音
        stopPlayingRecording()
        
        // 停止当前的播放
        pause()
        
        // 清理现有的音频引擎
        if let engine = audioEngine {
            if engine.isRunning {
                engine.inputNode.removeTap(onBus: 0)
                engine.stop()
            }
        }
        audioEngine = nil
        
        print("开始录音 - 当前歌词: \(lastLyricText)")
        
        do {
            // 创建新的音频引擎
            audioEngine = AVAudioEngine()
            
            // 配置音频会话
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth])
            try AVAudioSession.sharedInstance().setActive(true)
            
            // 设置录音文件
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            recordedFileURL = documentsPath.appendingPathComponent("recording.wav")
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: recordedFileURL!, settings: settings)
            audioRecorder?.delegate = self
            
            if audioRecorder?.prepareToRecord() == true {
                audioRecorder?.record()
                isRecording = true
                
                // 延迟启动语音识别
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.startSpeechRecognition()
                }
            }
        } catch {
            print("开始录音失败: \(error)")
            isRecording = false
        }
    }
    
    func stopRecording() {
        print("停止录音")
        print("原始歌词: \(lastLyricText)")
        print("最终识别文本: \(recognizedText)")
        
        // 停止音频引擎和录音
        audioEngine?.stop()
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        audioRecorder?.stop()
        isRecording = false
        
        // 重新配置音频会话
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            
            // 在停止录音后进行评分和保存
            if !lastLyricText.isEmpty, let lyricId = currentLyricId, let recordedURL = recordedFileURL {
                let finalRecognizedText = recognizedText.isEmpty ? lastRecognitionResult : recognizedText
                
                // 计算评分和匹配结果
                let score = scoreService.calculateScore(
                    originalLyric: lastLyricText,
                    recognizedText: finalRecognizedText
                )
                
                let matchResult = scoreService.generateMatchResult(
                    originalLyric: lastLyricText,
                    recognizedText: finalRecognizedText
                )
                
                // 更新当前显示的结果
                lastScore = score
                currentMatchResult = matchResult
                
                print("评分结果: \(String(describing: score))")
                print("匹配结果: \(String(describing: matchResult))")
                
                // 保存录音记录
                do {
                    try recordingManager.saveRecording(
                        lyricId: lyricId,
                        recordingURL: recordedURL,
                        recognizedText: finalRecognizedText,
                        score: score,
                        matchResult: matchResult
                    )
                    print("录音记录保存成功")
                } catch {
                    print("保存录音记录失败: \(error)")
                }
            }
            
            // 重新设置播放引擎
            if let url = audioFile?.url {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.setupEngine(with: url)
                    if let recordedURL = self?.recordedFileURL {
                        self?.generateRecordedWaveform(from: recordedURL)
                    }
                }
            }
        } catch {
            print("重置音频会话失败: \(error)")
        }
    }
    
    private func startSpeechRecognition() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("Speech recognition not available")
            return
        }
        
        guard let audioEngine = self.audioEngine else {
            print("Audio engine not initialized")
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create recognition request")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        do {
            try audioEngine.start()
            
            recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }
                
                if let result = result {
                    self.lastRecognitionResult = result.bestTranscription.formattedString
                    self.recognizedText = self.lastRecognitionResult
                    print("实时识别结果: \(self.recognizedText)")
                }
                
                if let error = error {
                    print("语音识别错误: \(error)")
                    // 如果是无语音错误，使用最后一次的识别结果
                    if (error as NSError).domain == "kAFAssistantErrorDomain" && 
                       (error as NSError).code == 1110 {
                        self.recognizedText = self.lastRecognitionResult
                    }
                }
            }
        } catch {
            print("语音识别启动失败: \(error)")
            audioEngine.stop()
            inputNode.removeTap(onBus: 0)
        }
    }
    
    private func generateRecordedWaveform(from url: URL) {
        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let frameCount = UInt32(file.length)
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
            try file.read(into: buffer)
            
            if let channelData = buffer.floatChannelData?[0] {
                let samples = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
                recordedWaveform = generateStaticWaveform(from: samples)
            }
        } catch {
            print("波形生成失败: \(error)")
        }
    }
    
    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: RecognitionLanguage.english.rawValue))
        
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("语音识别已授权")
                case .denied:
                    print("用户拒绝了语音识别权限")
                case .restricted:
                    print("语音识别在此设备上受限")
                case .notDetermined:
                    print("语音识别未授权")
                @unknown default:
                    print("未知的授权状态")
                }
            }
        }
    }
    
    func switchRecognitionLanguage(to language: RecognitionLanguage) {
        currentLanguage = language
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: language.rawValue))
        
        // 如果正在录音，重新启动语音识别
        if isRecording {
            stopRecording()
            if let currentLyricTime = Double(lastLyricText) {
                startRecording(startTime: currentLyricTime, endTime: duration)
            }
        }
    }
    
    deinit {
        // 安全地清理资源
        if let engine = audioEngine {
            if engine.isRunning {
                engine.inputNode.removeTap(onBus: 0)
                engine.stop()
            }
        }
        stopRecording()
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    func seekTo(time: Double) {
        print("seekTo - 目标时间: \(time)")
        guard let audioFile = self.audioFile,
              let player = playerNode,
              let engine = audioEngine else {
            print("seekTo - 音频组件未就绪")
            return
        }
        
        // 确保引擎在运行
        if !engine.isRunning {
            do {
                try engine.start()
                print("seekTo - 启动音频引擎")
            } catch {
                print("Error starting audio engine: \(error)")
                return
            }
        }
        
        let sampleRate = audioFile.processingFormat.sampleRate
        let sampleTime = AVAudioFramePosition(time * sampleRate)
        let frameCount = AVAudioFrameCount(audioFile.length - AVAudioFramePosition(sampleTime))
        
        print("seekTo - 当前播放状态: \(isPlaying)")
        player.stop()
        
        player.scheduleSegment(
            audioFile,
            startingFrame: sampleTime,
            frameCount: frameCount,
            at: nil
        )
        
        currentTime = time
        print("seekTo - 更新currentTime: \(currentTime)")
        
        if isPlaying {
            print("seekTo - 继续播放")
            player.play()
            startMonitoring()
        }
    }
    
    func playRecording() {
        guard let recordedFileURL = recordedFileURL else { return }
        
        do {
            // 停止主音频播放
            pause()
            
            // 配置音频会话
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            
            // 创建并播放录音
            recordedAudioPlayer = try AVAudioPlayer(contentsOf: recordedFileURL)
            recordedAudioPlayer?.delegate = self
            recordedAudioPlayer?.play()
            isPlayingRecording = true
        } catch {
            print("播放录音失败: \(error)")
        }
    }
    
    func stopPlayingRecording() {
        recordedAudioPlayer?.stop()
        isPlayingRecording = false
    }
    
    func setLoopRange(startTime: Double, endTime: Double) {
        loopStartTime = startTime
        loopEndTime = endTime
    }
    
    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        timePitch?.rate = rate
    }
}

extension AudioManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            print("录音完成")
        }
    }
}

extension AudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if player === recordedAudioPlayer {
            isPlayingRecording = false
        }
    }
} 
