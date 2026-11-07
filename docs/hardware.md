# Two-computer Pluto setup

## Wiring

```mermaid
flowchart LR
  A[TX computer / MATLAB] <-->|USB DATA port| B[Pluto A]
  B -->|TX antenna · radio channel| C[Pluto B]
  C <-->|USB DATA port| D[RX computer / MATLAB]
```

Connect **one Pluto per computer** using a USB data cable. On Pluto, use the connector marked with the USB trident, rather than the separate power-only connector. Fit the antennas to the labelled TX and RX connectors. The Ready indicator confirms boot; host enumeration must also succeed. [MathWorks hardware setup](https://www.mathworks.com/help/comm/plutoradio/ug/manual-host-radio-hardware-setup.html) covers driver installation and USB troubleshooting.

The original demonstration used a Windows laptop plus a Surface Pro 7 (8 GiB RAM). No computer-to-computer USB cable or network payload service is used by this application.

In MATLAB on each computer:

```matlab
setupLab;
radios = findPlutoRadio;
disp(radios);
```

Exactly one radio must be visible to each terminal. The program reads its serial number locally and uses it to address that radio. Do not publish generated captures/logs without checking their content: local records contain the current payload, device identifier, timestamps and scene notes.

## Operating sequence

1. Run `runPlutoTerminal('RX')` on the receiving computer and `runPlutoTerminal('TX')` on the transmitting computer.
2. Choose QPSK, BPSK or 2FSK on both sides. Begin with QPSK and a short text.
3. Enter the test scene in the scene field: approximate distance, placement, obstructions and trial number.
4. Click **开始接收** (Start receiving) on RX.
5. Enter text on TX, then click **发送内容** (Send). For a PNG, click **使用示例图片** (Use sample image) or **选择图片 / 文件** (Choose file).
6. Check the TX gain before sending. The existing file-selection action sets it to **0 dB**; select a lower value when appropriate for your setup. The default text gain is −10 dB.
7. Inspect the receiver's new result, frame counts and spectrum/constellation. **查看全过程（分步图解）** opens the stage plots; **打开接收文件** opens the recovered local file.
8. Use **停止** to stop early. The normal TX action stops after about 22 seconds. Repeat with swapped roles to test the opposite direction.

“上次接收” means **previous reception**. It reopens an explicitly labelled local historical record; it is not evidence of a new transmission. Starting a new operation clears the displayed content. To demonstrate a fresh transfer, change the payload and confirm a new run marker in both records.

## Limits and configuration

| Setting | Current terminal |
|---|---|
| RF center | 2.405 GHz on both computers |
| Baseband sample rate | 1 MS/s |
| RX gain | Manual, 30 dB |
| TX gain options | −30, −20, −10, 0 dB |
| BPSK / QPSK payload | Up to 1,024 bytes, text or file |
| 2FSK payload | Text up to 48 UTF-8 bytes |
| File transfer | Pre-existing file bytes; no image compression is performed by the terminal |
| Radio operation | One-way transfer per trial; roles can be exchanged |

The RF center is set at the `sdrtx` and `sdrrx` construction calls in `PlutoTerminal.m`; the record fields and UI labels use the same value. Change all of these consistently on both hosts if your permitted test channel differs. `plutoFskTransmit` / `plutoFskReceive` also expose explicit frequency and RadioID arguments for lower-level FSK work. Only transmit on a frequency and at a power permitted for your setting. A cable loopback requires appropriate attenuation; do not directly join TX and RX without it.

The GUI's output directory defaults to `results/hardware` under the checkout. To put captures on a separate data drive:

```matlab
setenv('PLUTO_LAB_OUTPUT_DIR', fullfile(pwd, 'results', 'my_radio_trials'));
runPlutoTerminal('RX');
```

Each capture can consume substantial disk space: a typical 16.05632-second run contains 16,056,320 complex IQ samples. Generated data is ignored by Git. Retain the trials needed for analysis and manage old captures locally.

## Diagnostic sequence

| Observation | First check |
|---|---|
| Lights on, no radio in MATLAB | USB data connector, data-capable cable, host driver; avoid an unpowered hub |
| Device discovery error | Exactly one radio per host; close other applications holding that device |
| Pilots absent | TX actually running, same RF center, antenna connection, selected modulation |
| Pilots detected, no complete file | Signal level, frequency tracking, incomplete fragments, capture overlap with TX |
| Overflow / invalid samples | Host load and USB transfer; discarded gaps cannot be treated as continuous data |
| Previous image still visible | Check whether the status says historical reception; start a fresh RX operation |

The receiver only opens its local radio. A useful control is to leave TX stopped while recording a new RX run, then repeat with a changed payload and TX enabled. Keep the trial conditions alongside the results.

## 中文操作摘要

每台电脑各接一台 Pluto 的 USB 数据口。两边 `findPlutoRadio` 识别成功后，分别打开 RX 和 TX 终端；调制方式相同，先接收、后发送。文字直接输入，图片使用小于等于 1,024 字节的 PNG。选择文件后会自动设为 0 dB 发射增益，请按测试条件手动调整。

“上次接收”是明确标注的历史结果。验证新传输时换一段新内容、重新接收，并查看新的无线标记和接收记录。两台电脑无需通过网络传载荷。
