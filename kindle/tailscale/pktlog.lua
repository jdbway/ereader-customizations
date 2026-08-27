-- Minimal raw-socket packet logger, written for a battery-drain
-- investigation where tcpdump wasn't an option (would've meant fetching
-- and running a precompiled third-party ARM binary as root - a line not
-- worth crossing just to save some debugging time). LuaJIT's FFI can call
-- socket()/bind()/recv() directly, so this is source we control instead,
-- running through an interpreter that's already trusted and present
-- (KOReader itself runs on this exact luajit).
--
-- Opens an AF_PACKET raw socket on the given interface, does a minimal
-- manual Ethernet/IPv4/TCP/UDP header parse (no libpcap), and appends one
-- line per matching packet to the output file. Filters to only frames
-- sourced from a given MAC address (arg 4) - without that, a raw socket
-- sees the whole broadcast domain (every device's traffic it can hear),
-- not just the one device you actually want to attribute tx_packets to.
--
-- Usage: luajit pktlog.lua <duration_seconds> <iface> <outpath> [own_mac]
local ffi = require("ffi")
local bit = require("bit")

ffi.cdef[[
typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;

int socket(int domain, int type, int protocol);
int bind(int sockfd, const void *addr, unsigned int addrlen);
long recv(int sockfd, void *buf, unsigned long len, int flags);
unsigned int if_nametoindex(const char *ifname);
u16 htons(u16 hostshort);
int close(int fd);

struct sockaddr_ll {
    u16 sll_family;
    u16 sll_protocol;
    int sll_ifindex;
    u16 sll_hatype;
    u8  sll_pkttype;
    u8  sll_halen;
    u8  sll_addr[8];
};
]]

local AF_PACKET = 17
local SOCK_RAW = 3
local ETH_P_ALL = 0x0003

local duration = tonumber(arg[1]) or 60
local iface = arg[2] or "wlan0"
local outpath = arg[3] or "/tmp/pktlog.txt"
local own_mac = arg[4] -- e.g. "b0:8b:a8:88:19:8f" - if set, only log frames sourced from this MAC (i.e. genuine TX activity)

local function macMatches(buf, mac)
    if not mac then return true end
    local parts = {}
    for byte in mac:gmatch("%x%x") do parts[#parts + 1] = tonumber(byte, 16) end
    for i = 0, 5 do
        if buf[6 + i] ~= parts[i + 1] then return false end
    end
    return true
end

local ifindex = ffi.C.if_nametoindex(iface)
if ifindex == 0 then
    print("failed to resolve interface " .. iface)
    os.exit(1)
end

local sockfd = ffi.C.socket(AF_PACKET, SOCK_RAW, ffi.C.htons(ETH_P_ALL))
if sockfd < 0 then
    print("socket() failed - need root")
    os.exit(1)
end

local addr = ffi.new("struct sockaddr_ll")
addr.sll_family = AF_PACKET
addr.sll_protocol = ffi.C.htons(ETH_P_ALL)
addr.sll_ifindex = ifindex

if ffi.C.bind(sockfd, addr, ffi.sizeof(addr)) < 0 then
    print("bind() failed")
    os.exit(1)
end

local buf = ffi.new("unsigned char[?]", 65536)
local logf = io.open(outpath, "a")

local function u16be(b, off)
    return b[off] * 256 + b[off + 1]
end

local proto_names = { [6] = "TCP", [17] = "UDP", [1] = "ICMP", [2] = "IGMP" }
local TIMESTAMP_FMT = "%Y-%m-%d %H:%M:%S"

local start = os.time()
local count = 0
while os.time() - start < duration do
    local n = ffi.C.recv(sockfd, buf, 65536, 0)
    if n and n > 14 and macMatches(buf, own_mac) then
        local ethertype = u16be(buf, 12)
        if ethertype == 0x0800 then
            local ihl = bit.band(buf[14], 0x0f) * 4
            local proto = buf[14 + 9]
            local src = string.format("%d.%d.%d.%d", buf[26], buf[27], buf[28], buf[29])
            local dst = string.format("%d.%d.%d.%d", buf[30], buf[31], buf[32], buf[33])
            local sport, dport = 0, 0
            if (proto == 6 or proto == 17) and n >= 14 + ihl + 4 then
                sport = u16be(buf, 14 + ihl)
                dport = u16be(buf, 14 + ihl + 2)
            end
            logf:write(string.format("%s %s len=%d %s:%d -> %s:%d\n",
                os.date(TIMESTAMP_FMT), proto_names[proto] or ("proto" .. proto), n, src, sport, dst, dport))
        elseif ethertype == 0x0806 then
            logf:write(string.format("%s ARP len=%d\n", os.date(TIMESTAMP_FMT), n))
        elseif ethertype == 0x86dd then
            logf:write(string.format("%s IPv6 len=%d\n", os.date(TIMESTAMP_FMT), n))
        else
            logf:write(string.format("%s ethertype=0x%04x len=%d\n", os.date(TIMESTAMP_FMT), ethertype, n))
        end
        count = count + 1
        if count % 20 == 0 then logf:flush() end
    end
end

logf:write(string.format("=== capture ended, %d packets in %ds ===\n", count, duration))
logf:close()
ffi.C.close(sockfd)
