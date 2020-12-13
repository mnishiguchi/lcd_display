# https://hexdocs.pm/mox/Mox.html#module-compile-time-requirements
Mox.defmock(LcdDisplay.MockGPIO, for: LcdDisplay.CommunicationBus.GPIO)
Mox.defmock(LcdDisplay.MockI2C, for: LcdDisplay.CommunicationBus.I2C)

Mox.defmock(LcdDisplay.MockDisplayDriver, for: LcdDisplay.DisplayDriver)
