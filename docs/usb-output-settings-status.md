# USB 输出设置接入状态

本文档记录 `USB 输出设置` 页面里哪些项目已经接入真实链路，哪些只是先放在 UI 和偏好层，作为后续 USB 独占链路改造的参考。

## 已接入运行链路

| 项目 | 状态 | 说明 |
| --- | --- | --- |
| Android USB 插入声明 | 已接入 | `AndroidManifest.xml` 已声明 `android.hardware.usb.action.USB_DEVICE_ATTACHED`，`usb_audio_device_filter.xml` 已包含 USB Audio Class 和 Macaron VID/PID。`dumpsys usb` 能看到 `com.afalphy.sylvakru.debug` 注册到 `device_attached_activities`。 |
| USB 设备识别 | 已接入 | 通过 Android 侧 USB/AudioDevice 状态回传，设置页能显示 DAC 名称、USB ID、系统输出设备、采样率和编码等信息。 |
| USB 权限与独占诊断 | 已接入 | `probeExclusiveAccess()` 会检查 USB 权限、Audio Interface 数量、claim 能力和原始描述符长度。 |
| 固定采样率输出 | 部分接入 | 偏好已用于 `preferredExclusiveSampleRate()` 和系统 preferred output 请求；真实独占写流仍要看底层能力是否支持对应采样率。 |
| PCM 位深偏好 | 部分接入 | `UsbAudioPreferences.preferredEncoding()` 会把 `16/24/32 bits` 映射到 Android PCM encoding，用于输出偏好请求。 |
| USB 独占播放状态 | 已接入快照 | `UsbExclusivePlaybackState` 会由 start/pause/resume/seek/stop 等 native 调用回传，页面监听这个 notifier 展示当前快照。它不是连续实时水位。 |
| 后台保活 | 已接入偏好 | 偏好已持久化，并用于 App 内 USB 输出策略判断；是否能完全防止系统杀后台取决于系统电池策略。 |
| 播放后释放 USB 带宽 | 已接入偏好 | 偏好已保存，供停止播放后释放 USB 资源策略使用。 |
| DSD 模式和 DSD 转 PCM 采样率 | 已接入偏好 | `PCM / DoP / Native` 和 DSD64/128/256/512 转 PCM 目标采样率均已持久化。底层 Native DSD/DoP 是否真正输出取决于后续独占链路实现。 |
| 音量锁定和 DSD 增益补偿 | 已接入偏好 | 设置已持久化，供播放链路读取；硬件音量实时检测暂未接入。 |

## 参考或占位项

| 项目 | 状态 | 当前用途 |
| --- | --- | --- |
| 位深兼容 | UI/偏好占位 | 可保存，用于后续在独占链路里按 DAC 能力回退位深。当前不直接改变 PCM 数据写入。 |
| 采样率兼容 | UI/偏好占位 | 可保存，用于后续按 DAC 支持列表自动回退采样率。当前主要还是固定采样率和系统 preferred output 在生效。 |
| 声道兼容 | UI/偏好占位 | 可保存，用于后续处理单声道/多声道回退。当前不做实际声道重排。 |
| TPDF 抖动 | UI/偏好占位 | 可保存，但当前没有接入高位深转 16-bit 的音频处理链路。 |
| 前台缓冲区 / 后台缓冲区 | UI/偏好占位 | 可保存，并用于设置页显示目标水位；当前未接入底层 USB isochronous 写入队列。 |
| 音量平滑交接 | UI/偏好占位 | 可保存，用于后续数字音量和 DAC 硬件音量切换时做淡入淡出。当前没有实时硬件音量检测。 |
| 延迟建立 USB 输出链路 | UI/偏好占位 | 可保存，用于后续把 claim/open endpoint 推迟到播放开始。当前不改变建链时机。 |
| USB 总线速度 | UI/偏好占位 | 可保存，用于后续诊断或策略选择。普通 Android App 通常不能强制 USB bus speed。 |
| DAC 端点格式 | 信息占位 | 无独占播放时显示系统/设备能力；真实 endpoint alt setting 需要底层能力解析后再展示。 |

## 传输状态卡说明

传输状态卡现在按快照表达，不再伪装成实时仪表：

- 主数值：`UsbExclusivePlaybackState.position`，目前代表 native 回传的播放/水位快照。
- 状态：`active + playing` 显示为稳定，`active + !playing` 显示为暂停，否则为待机。
- ISO：当前没有底层 isochronous 传输实时计数，固定显示 `ISO 0`。
- 目标：来自前台缓冲区偏好，默认 `200 ms`，只作为目标水位参考。
- 最低：当前没有底层最低水位统计，播放中暂用本次快照值；待机显示 `最低 --`。

如果后续要让它真正实时，需要 native 层周期性上报 USB 写入队列水位、iso packet 计数、underrun 次数和最低水位，再更新 `UsbExclusivePlaybackState` 或新增专门的传输 telemetry notifier。
