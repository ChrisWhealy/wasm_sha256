#!/usr/bin/env node

import { readFileSync, writeFileSync } from 'node:fs'

const src = readFileSync('./src/sha256.wat', 'utf8')
const stripped = src
  .replace(/[ \t]*;;@debug-start[\s\S]*?;;@debug-end[^\n]*\n/g, '')
  .replace(/\n{3,}/g, '\n\n')

writeFileSync('./src/sha256.prod.wat', stripped)
