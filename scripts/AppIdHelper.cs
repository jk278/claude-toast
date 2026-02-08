using System;
using System.Runtime.InteropServices;

public class AppIdHelper
{
    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    public static extern int SHGetPropertyStoreFromParsingName(
        string pszPath,
        IntPtr pbc,
        uint flags,
        ref Guid riid,
        out IPropertyStore ppv);

    [Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IPropertyStore
    {
        int GetCount(out uint cProps);
        int GetAt(uint iProp, out PROPERTYKEY pkey);
        int GetValue(ref PROPERTYKEY pkey, out PROPVARIANT pv);
        int SetValue(ref PROPERTYKEY pkey, ref PROPVARIANT pv);
        int Commit();
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct PROPERTYKEY
    {
        public Guid fmtid;
        public uint pid;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct PROPVARIANT
    {
        public ushort vt;
        public ushort wReserved1;
        public ushort wReserved2;
        public ushort wReserved3;
        public IntPtr pszVal;
    }

    private const uint GPS_READWRITE = 0x2;

    public static bool SetAppId(string path, string appId)
    {
        try
        {
            Guid iid = new Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99");
            IPropertyStore store;
            int hr = SHGetPropertyStoreFromParsingName(path, IntPtr.Zero, GPS_READWRITE, ref iid, out store);
            if (hr != 0) return false;

            PROPERTYKEY key;
            key.fmtid = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3");
            key.pid = 5;

            PROPVARIANT val = new PROPVARIANT();
            val.vt = 31;
            val.pszVal = Marshal.StringToCoTaskMemUni(appId);

            store.SetValue(ref key, ref val);
            store.Commit();

            Marshal.FreeCoTaskMem(val.pszVal);
            Marshal.ReleaseComObject(store);

            return true;
        }
        catch
        {
            return false;
        }
    }
}
