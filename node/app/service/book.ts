import { Book as BookType, Service } from 'egg';
import BOOK_LIST from '../assets/json/book.json';

/**
 * Book Service
 */
export default class Book extends Service {
  /**
   * 获取书籍详情
   * @param bookId - 书ID
   */
  public async getBookById(bookId: number): Promise<BookType> {
    if (!bookId) {
      throw {
        code: 'PARAM_ERROR',
        msg: '参数bookId无效',
      };
    }

    const book = BOOK_LIST.find(item => item.id === bookId);
    if (!book) {
      throw {
        code: 'PARAM_ERROR',
        msg: '参数bookId错误',
      };
    }

    return book;
  }
}
