export default {
  getBookById: (bookId: number | string) => `/book/${bookId}`,
  getChapterById: (chapterId: number | string) => `/chapter/${chapterId}`,
  getChapterListByBookId: (bookId: number | string) => `/chapter/book/${bookId}`,
}
