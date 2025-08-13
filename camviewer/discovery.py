from wsdiscovery.discovery import ThreadedWSDiscovery as WSD
from wsdiscovery import QName
from dataclasses import dataclass
from typing import List

@dataclass
class FoundDevice:
    epr: str
    xaddrs: List[str]
    scopes: List[str]
    address: str

def discover_onvif(timeout_s: int = 4) -> List[FoundDevice]:
    # Type filter for ONVIF devices (NetworkVideoTransmitter is common)
    types = [QName("NetworkVideoTransmitter", "dn:")]
    wsd = WSD()
    wsd.start()
    try:
        services = wsd.searchServices(types=types, timeout=timeout_s)
        out: List[FoundDevice] = []
        for s in services:
            addr = s.getXAddrs()[:1][0] if s.getXAddrs() else ""
            out.append(FoundDevice(
                epr=str(s.getEPR()),
                xaddrs=s.getXAddrs(),
                scopes=[str(x) for x in s.getScopes() or []],
                address=addr
            ))
        return out
    finally:
        wsd.stop()
