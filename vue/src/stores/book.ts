import { ref, computed, reactive } from 'vue'
import { defineStore } from 'pinia'
import BOOK_LIST from '@/assets/book/book.json'
import CHAPTER_LIST from '@/assets/book/chapter.json'
console.log(BOOK_LIST, CHAPTER_LIST)

export const bookStore = defineStore('book', () => {
  const bookList = reactive(BOOK_LIST)
  const chapterList = reactive(CHAPTER_LIST)
  bookList.forEach((book) => {
    let count = 0
    chapterList.forEach((chapter) => {
      if (book.id === chapter.bookId) {
        count += chapter.wordCount
      }
    })
    book.wordCount = count
  })

  function getBookById(bookId: number) {
    return bookList.some((book) => book.id === bookId) || null
  }

  return { bookList, getBookById }
})
