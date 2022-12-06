export default {
  getBookById: (bookId: number | string) => `/book/${bookId}`,
  getChapterById: (bookId: number | string, chapterId: number | string) => `/book/${bookId}/chapter/${chapterId}`,
  getChapterListByBookId: (bookId: number | string) => `/book/${bookId}/chapter`,
  getAuthorByBookId: (bookId: number | string) => `/author/${bookId}`,
}
