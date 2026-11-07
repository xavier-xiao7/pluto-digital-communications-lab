# Tests, measurements and interpretation

## Reproducing the software checks

From the repository root in MATLAB:

```matlab
setupLab;
summary = runPublicChecks;
```

This runs protocol boundary/corruption checks, portable offline-audio checks, independent PSK receiver waveforms, 12 simulation demonstrations, the Pluto FSK software adapter suite, synthesized BPSK/QPSK radio-waveform decoding, and construction of both UIs. The test does not open a radio or use a soundcard device. Assertions stop the run on a mismatch; results are written under `results/checks`.

For the larger experiment matrices:

```matlab
runAllExtensions(fullfile(pwd,'results','all_extensions'));
validateFskExperiment(fullfile(pwd,'results','fsk_matrix'));
```

Use separate result directories to preserve earlier runs. The seed, configuration and failed conditions belong with the results. A failed recovery in an optional difficult-channel case is an expected measurement outcome; an exception or a failed required baseline is a software-check failure.

## Public-release validation

The release is tested from this independent checkout, using generated Simulink models and neutral sample payloads. Results are recorded in [release-validation.json](release-validation.json): 12/12 demonstrations, 13 protocol checks, 9 portable checks, 7 independent PSK waveforms, 10 Rician conditions, 13/13 FSK adapter waveforms, two PSK radio-waveform checks and both UI constructors completed. The complete-link matrices also finished: 35/35 required advanced cases passed (46/57 complete recoveries overall), and all 9 FSK baselines passed (24/33 complete recoveries overall). Optional failed recoveries are retained in the result summary. The file contains summarized software results, not personal payloads or hardware identifiers.

## Earlier simulation observations

These measurements were obtained during development before preparing the public checkout. The public sample text differs, so a fresh run should be interpreted from its own output files.

| Study | Observed result | Scope |
|---|---|---|
| 2FSK complete-link matrix | 33 conditions; 9 required baselines passed; 23 complete recoveries and 10 incomplete recoveries overall | Software Simulink chain |
| FSK timing comparison | At the tested ±2,000 ppm offsets, timing-loop receiver recovered 8/8 frame copies, fixed sampling recovered 0/8 | Specific offline clock-error comparison |
| FSK AWGN benchmark | 2.8 million known-timing bits compared with the noncoherent orthogonal FSK reference | Controlled detection benchmark; not measured radio BER |
| Advanced complete-link matrix | 57 conditions; 35/35 required cases recovered; 11/22 optional single-pass difficult cases recovered; zero software exceptions | Software BPSK/QPSK chain |
| Long payloads | 5,330-byte text, generated PNG and PCM WAV recovered under the tested baseline configuration | File bytes in simulation; not live audio |
| Coding comparison | Interleaving enabled recovery of the tested burst; equal-information-energy random BER did not show an SECDED gain | Avoid comparing coded/uncoded curves at unequal information-bit energy |
| Audio interface | Generated WAV write/read, clock offset and stereo-channel cases | Offline only; no physical audio cable measurement |

The advanced default configuration repeats the frame set so the decoder can collect fragments from different passes. This provides time diversity under fading. It does not mean every copy succeeds or that a carrier loop removes a deep fade.

## Earlier two-radio observations

Equipment: two ADALM-Pluto modules with antennas, each attached by USB to its own Windows computer. Software used MATLAB R2025a, the Pluto support package and the ADI USB driver. The RF center was 2.405 GHz and the baseband sample rate 1 MS/s.

| Trial family | Observation | Placement / interpretation |
|---|---|---|
| 2FSK text | Valid text recovered from locally captured radio IQ | Indoor testing, including the recorded approximately 3 m horizontal / 0.8 m height-difference arrangement |
| BPSK / QPSK text | Successful text trials; QPSK also demonstrated in the reverse direction | Separate independent radios; earlier failed acquisitions also occurred during tuning |
| Two synthetic PNG trials | 871 bytes each recovered in QPSK; 5 and 6 CRC-valid copies respectively; zero overflow/invalid frames in those captures | Approximately 3 m horizontal distance, one unit at desk level and one near floor level, about 0.8 m height difference; not a through-wall range study |
| Quiet control after PNG trials | No valid frame copies | TX stopped, fresh receive capture |
| Indexed PNG transfer | 990-byte file recovered exactly, 5 fragments, 12 CRC-valid copies | Separate close desktop setup; do not assign the 3 m distance to this trial |

The 990-byte file was prepared before transmission by resizing/indexed-color encoding. The terminal transported those existing bytes. It did not send the original 42,267-byte source image and did not run an image reconstruction model.

The corresponding capture contained **16,056,320 complex samples** over **16.05632 s**, with no recorded overflow or invalid frames. The 5 fragments had accepted-copy counts of **3, 2, 2, 2, 3**. Four bit corrections were reported across the accepted copies. A later decode starting only from the stored IQ reproduced the file; the decoder did not read the source image or a previous decoded result.

Source images and raw captures are not distributed here. These are summarized development observations, not measurements repeated during public-release packaging and not a public range/BER dataset.

## Why exact files can coexist with an imperfect radio channel

The receiver makes symbol decisions and rejects invalid frames. Correctable errors are repaired, and later valid copies can supply a missing fragment. Only a complete message passing the final integrity check is displayed as complete. An incomplete transfer remains incomplete.

For the 990-byte example, QPSK mapped **6,000 bit/s** before protocol overhead. The transmit buffer lasted **6.546021 s** and the actual TX-on interval was **22.313 s**. Counting the original file's bits over TX-on time gives approximately **355 useful bit/s**:

```text
990 bytes × 8 / 22.313 seconds ≈ 355 bit/s
```

Headers, training, forward-error correction, guard intervals and repeated playback account for the difference. Byte-for-byte recovery therefore demonstrates integrity of the completed transfer, not high raw-channel reliability or high useful throughput.

## Negative controls and remaining limits

The protocol tests reject missing fragments, mixed messages, conflicting copies, corrupt headers, invalid CRCs and complete-message integrity mismatches. Earlier IQ replay checks also rejected zero samples, noise alone and the two calibration tones without data. Removing every copy of a required fragment prevented completion.

The demonstrated setup is a short-range laboratory link, with a small-file cap and manual TX/RX sequencing. It has no authenticated/encrypted transport, automatic channel selection, ARQ feedback or continuous video mode. The simulated fading model is single-path and does not cover a rich multipath channel. Other MATLAB releases, operating systems and sustained radio throughput have not been validated here.

## 中文说明

`runPublicChecks` 是软件检查，不会调用射频或声卡硬件。历史仿真、历史射频和公开版复验分别记录；历史失败条件保留。接收机通过纠错、CRC、分片补齐和最终内容校验，才报告完整文件。完整文件并不代表每一个接收比特都正确。

3 m / 0.8 m 是部分室内摆位的记录；990 字节图片的独立解码对应另一组近距离桌面测试。该图片发送前已缩小并转为索引色；程序只传输处理后的文件字节。使用 22.313 秒发射时间计算，净载荷速率约为 355 bit/s，不能把 QPSK 的 6 kbit/s 映射速率当作文件净速率。
