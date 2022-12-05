/// <reference types="vite/client" />

import '@vue/runtime-core'
import { AxiosInstance } from 'axios'

declare module '@vue/runtime-core' {
  interface ComponentCustomProperties {
    $axios: AxiosInstance
  }
}

declare interface DefaultResponse {
  code: number
  msg: string
  data: any
}

declare interface Chapter {
  id?: number
  name?: string
  bookName?: string
  authorName?: string
  wordCount?: number
  bookId?: number
  file?: string
  time?: string
  txtString?: string
}
declare interface Book {
  id?: number
  name?: string
  type?: string[]
  state?: number
  wordCount?: number
  reader?: number
  authorId?: number
  description?: string
}
