import { Chapter as ChapterType, Service } from 'egg';
import path from 'path';
import BOOK_LIST from '../assets/json/book.json';

/**
 * Chapter Service
 */
export default class Chapter extends Service {
  /**
   * 获取章节目录
   * @param bookId - 书ID
   */
  public async getChapterListByBookId(bookId: number): Promise<ChapterType[]> {
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
    try {
      const { default: chapterList } = await import(
        path.join(this.config.txtPath, book.name, this.config.chapterJsonName)
      );
      return chapterList;
    } catch (error) {
      this.logger.error(error);
      throw {
        code: 'PARAM_ERROR',
        msg: '参数bookId未找到对应章节文件',
      };
    }
  }
  /**
   * 获取章节详情
   * @param bookId - 书ID
   */
  public async getChapterById(bookId: number, chapterId: number): Promise<ChapterType> {
    const chapterList = await this.getChapterListByBookId(bookId);

    if (!chapterId) {
      throw {
        code: 'PARAM_ERROR',
        msg: '参数chapterId错误',
      };
    }

    const chapter = chapterList.find(item => item.id === chapterId);
    if (!chapter) {
      throw {
        code: 'PARAM_ERROR',
        msg: '参数chapterId错误',
      };
    }

    return chapter;
  }
}
