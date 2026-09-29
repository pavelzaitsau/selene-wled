# Hardware

A 104-LED strip runs around the back of an LG ULTRAFINE 27". An ESP32 drives it with WLED. The
board's WLED settings are in [the firmware README](../firmware/esp32/README.md).

## Parts

| Part | Notes |
| --- | --- |
| Controller | ESP32-D0WD-V3 (WROOM), 4 MB flash, USB serial as `/dev/cu.usbserial-*` |
| LED strip | 5 V, WS2812B-compatible, GRB, 104 LEDs |
| Power | USB-C PD trigger at 5 V, 3 A at most, 1000 uF across the input |
| Data | GPIO18 (pin D18) through 330 ohm to DIN |

## Wiring

The strip wires use non-standard colours:

| Wire | Signal |
| --- | --- |
| Red | +5 V |
| Yellow | GND |
| Black | DIN |

Switch the 5 V supply off before connecting USB to the ESP32. The reason for the rule is not
recorded yet, see [requirements.md](requirements.md#open-questions).

## LED order

LED 0 sits in the bottom-left corner. The strip runs clockwise as seen from the front:

| Side | Direction | LEDs | Indices |
| --- | --- | --- | --- |
| Left | bottom to top | 18 | 0-17 |
| Top | left to right | 34 | 18-51 |
| Right | top to bottom | 18 | 52-69 |
| Bottom | right to left | 34 | 70-103 |

Every client sends colours in this order. [tools/test-pattern.html](../tools/test-pattern.html)
paints each side a different colour and runs a dot around the edge. Open it full screen on the
monitor to check the order.
