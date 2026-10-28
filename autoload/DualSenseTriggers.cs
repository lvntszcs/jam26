using System;
using System.Linq;
using Godot;
using HidSharp;

/// <summary>
/// DualSense adaptive triggers, written straight to the controller over HID
/// (Godot has no API for them). Only the trigger fields of the output report
/// are flagged valid, so Godot's own rumble and light bar keep working.
///
/// Positions are trigger travel zones 0 (released) .. 9 (fully pressed),
/// strengths are 1 (light) .. 8 (max). Called from GDScript through DualSense.gd.
/// </summary>
public partial class DualSenseTriggers : Node
{
    public const int Left = 0;
    public const int Right = 1;

    private const int SonyVendor = 0x054C;
    private static readonly int[] DualSenseProducts = { 0x0CE6, 0x0DF2 }; // DualSense, DualSense Edge

    private const byte ModeOff = 0x05;
    private const byte ModeFeedback = 0x21;
    private const byte ModeWeapon = 0x25;
    private const byte ModeVibration = 0x26;

    private const int UsbReportSize = 48;
    private const int BtReportSize = 78;
    private const double ReconnectInterval = 1.0;
    // Godot's own rumble/light reports can reset the trigger state, so keep reasserting it.
    private const double ResendInterval = 0.2;

    private HidStream? _stream;
    private bool _bluetooth;
    private int _reportLength;
    private byte _btSeq;
    private double _sinceReconnect = ReconnectInterval;
    private double _sinceResend;
    // Last effect per trigger, resent after a reconnect.
    private readonly byte[][] _effects = { OffEffect(), OffEffect() };

    public bool HasController() => _stream != null;

    public override void _Process(double delta)
    {
        if (_stream != null)
        {
            _sinceResend += delta;
            if (_sinceResend >= ResendInterval)
                Send();
            return;
        }
        _sinceReconnect += delta;
        if (_sinceReconnect >= ReconnectInterval)
        {
            _sinceReconnect = 0;
            if (TryOpen())
                Send();
        }
    }

    public override void _Notification(int what)
    {
        if (what == NotificationWMCloseRequest || what == NotificationPredelete)
        {
            OffAll();
            _stream?.Dispose();
            _stream = null;
        }
    }

    /// <summary>Trigger moves freely.</summary>
    public void Off(int trigger) => SetEffect(trigger, OffEffect());

    public void OffAll()
    {
        _effects[Left] = OffEffect();
        _effects[Right] = OffEffect();
        Send();
    }

    /// <summary>Constant resistance from `start` to the end: something heavy to push.</summary>
    public void Resistance(int trigger, int start, int strength)
    {
        start = Math.Clamp(start, 0, 9);
        var force = (uint)(Math.Clamp(strength, 1, 8) - 1);
        uint zones = 0, forces = 0;
        for (var i = start; i < 10; i++)
        {
            zones |= 1u << i;
            forces |= force << (3 * i);
        }
        var e = NewEffect(ModeFeedback);
        WriteZones(e, zones, forces);
        SetEffect(trigger, e);
    }

    /// <summary>
    /// Resistance that ramps from `startStrength` at `start` to `endStrength` at the end
    /// of travel: the harder you press, the heavier it gets.
    /// </summary>
    public void Ramp(int trigger, int start, int startStrength, int endStrength)
    {
        start = Math.Clamp(start, 0, 9);
        uint zones = 0, forces = 0;
        for (var i = start; i < 10; i++)
        {
            var t = start == 9 ? 1f : (i - start) / (9f - start);
            var s = (uint)(Mathf.RoundToInt(Mathf.Lerp(startStrength, endStrength, t)) - 1);
            zones |= 1u << i;
            forces |= Math.Clamp(s, 0u, 7u) << (3 * i);
        }
        var e = NewEffect(ModeFeedback);
        WriteZones(e, zones, forces);
        SetEffect(trigger, e);
    }

    /// <summary>
    /// Free travel, then a hard wall at `start` that snaps through at `end`
    /// (a stuck mechanism or a gun trigger). start 2..7, end start+1..8.
    /// </summary>
    public void Snap(int trigger, int start, int end, int strength)
    {
        start = Math.Clamp(start, 2, 7);
        end = Math.Clamp(end, start + 1, 8);
        var zones = (1u << start) | (1u << end);
        var e = NewEffect(ModeWeapon);
        e[1] = (byte)(zones & 0xFF);
        e[2] = (byte)(zones >> 8);
        e[3] = (byte)(Math.Clamp(strength, 1, 8) - 1);
        SetEffect(trigger, e);
    }

    /// <summary>Trigger buzzes from `start` on: grinding, jammed, engine stalling.</summary>
    public void Vibrate(int trigger, int start, int amplitude, int frequencyHz)
    {
        start = Math.Clamp(start, 0, 9);
        var amp = (uint)(Math.Clamp(amplitude, 1, 8) - 1);
        uint zones = 0, amps = 0;
        for (var i = start; i < 10; i++)
        {
            zones |= 1u << i;
            amps |= amp << (3 * i);
        }
        var e = NewEffect(ModeVibration);
        WriteZones(e, zones, amps);
        e[9] = (byte)Math.Clamp(frequencyHz, 1, 255);
        SetEffect(trigger, e);
    }

    // --- Internals ---------------------------------------------------------

    private static byte[] NewEffect(byte mode)
    {
        var e = new byte[11];
        e[0] = mode;
        return e;
    }

    private static byte[] OffEffect() => NewEffect(ModeOff);

    private static void WriteZones(byte[] e, uint zones, uint values)
    {
        e[1] = (byte)(zones & 0xFF);
        e[2] = (byte)(zones >> 8);
        e[3] = (byte)(values & 0xFF);
        e[4] = (byte)(values >> 8);
        e[5] = (byte)(values >> 16);
        e[6] = (byte)(values >> 24);
    }

    private void SetEffect(int trigger, byte[] effect)
    {
        _effects[trigger == Left ? Left : Right] = effect;
        Send();
    }

    private bool TryOpen()
    {
        var device = DeviceList.Local.GetHidDevices(SonyVendor)
            .FirstOrDefault(d => DualSenseProducts.Contains(d.ProductID));
        if (device == null)
            return false;
        try
        {
            // Windows wants writes padded to the longest output report the device declares.
            _reportLength = device.GetMaxOutputReportLength();
            _bluetooth = _reportLength >= BtReportSize;
            _stream = device.Open();
            _stream.WriteTimeout = 100;
            GD.Print($"DualSenseTriggers: connected over {(_bluetooth ? "Bluetooth" : "USB")}");
            return true;
        }
        catch (Exception ex)
        {
            GD.PushWarning($"DualSenseTriggers: could not open controller: {ex.Message}");
            _stream = null;
            return false;
        }
    }

    private void Send()
    {
        if (_stream == null)
            return;
        _sinceResend = 0;
        var report = _bluetooth ? BuildBluetooth() : BuildUsb();
        try
        {
            _stream.Write(report);
        }
        catch (Exception)
        {
            // Unplugged or powered off: _Process reconnects and resends.
            _stream.Dispose();
            _stream = null;
        }
    }

    // Common output payload (shared by USB and Bluetooth), see hid-playstation.c.
    private void WriteCommon(byte[] report, int offset)
    {
        report[offset] = 0x04 | 0x08; // valid_flag0: right + left trigger effect
        Array.Copy(_effects[Right], 0, report, offset + 10, 11);
        Array.Copy(_effects[Left], 0, report, offset + 21, 11);
    }

    private byte[] BuildUsb()
    {
        var report = new byte[Math.Max(UsbReportSize, _reportLength)];
        report[0] = 0x02;
        WriteCommon(report, 1);
        return report;
    }

    private byte[] BuildBluetooth()
    {
        var report = new byte[Math.Max(BtReportSize, _reportLength)];
        report[0] = 0x31;
        report[1] = (byte)(_btSeq << 4);
        report[2] = 0x10; // output tag
        _btSeq = (byte)((_btSeq + 1) & 0x0F);
        WriteCommon(report, 3);
        // Bluetooth reports end with CRC32 over a 0xA2 header byte + the report.
        var crc = Crc32(0xA2, report, BtReportSize - 4);
        BitConverter.GetBytes(crc).CopyTo(report, BtReportSize - 4);
        return report;
    }

    private static uint Crc32(byte seed, byte[] data, int length)
    {
        var crc = 0xFFFFFFFFu;
        crc = CrcByte(crc, seed);
        for (var i = 0; i < length; i++)
            crc = CrcByte(crc, data[i]);
        return ~crc;
    }

    private static uint CrcByte(uint crc, byte b)
    {
        crc ^= b;
        for (var k = 0; k < 8; k++)
            crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320u : crc >> 1;
        return crc;
    }
}
