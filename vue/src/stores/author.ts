import { getCurrentInstance, type ComponentInternalInstance } from 'vue'
import { defineStore } from 'pinia'
import URL from '@/utils/url'
import type { DefaultResponse } from 'env'

export const authorStore = defineStore('author', () => {
  const { proxy } = getCurrentInstance() as ComponentInternalInstance

  async function getAuthorByBookId(bookId: number | string): Promise<DefaultResponse> {
    return (await proxy?.$axios.get(URL.getAuthorByBookId(bookId))) as DefaultResponse
  }
  return { getAuthorByBookId }
})
