import Config

# Use the mocks defined in test/support/mocks.ex
# https://hexdocs.pm/mox/Mox.html
config :lcd_display,
  gpio_module: LcdDisplay.MockGPIO,
  i2c_module: LcdDisplay.MockI2C,
  spi_module: LcdDisplay.MockSPI,
  display_driver: LcdDisplay.MockHD44780
