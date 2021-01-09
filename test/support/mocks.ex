# https://hexdocs.pm/mox/Mox.html#module-compile-time-requirements
Mox.defmock(LcdDisplay.MockGPIO, for: LcdDisplay.GPIO.Behaviour)
Mox.defmock(LcdDisplay.MockI2C, for: LcdDisplay.I2C.Behaviour)

Mox.defmock(LcdDisplay.MockDriver, for: LcdDisplay.Driver)
