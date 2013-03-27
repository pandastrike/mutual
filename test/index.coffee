fs = require 'fs'

files = fs.readdirSync __dirname

for file in files when /^test-/.test file
  require "./#{file}"

