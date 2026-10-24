import Testing
import EarmarkShared

@Test("App can see the shared interface")
func appSeesSharedInterface() {
    #expect(AudioChunk.sampleRate == 16_000)
}
