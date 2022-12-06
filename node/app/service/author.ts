import { Author as AuthorType, Service } from 'egg';
import AUTHOR_LIST from '../assets/json/author.json';

/**
 * Author Service
 */
export default class Author extends Service {
  /**
   * 获取作者详情
   * @param authorId - 作者ID
   */
  public async getAuthorById(authorId: number): Promise<AuthorType> {
    if (!authorId) {
      throw {
        code: 'PARAM_ERROR',
        msg: '参数authorId错误',
      };
    }

    const author = AUTHOR_LIST.find(item => item.id === authorId);
    if (!author) {
      throw {
        code: 'PARAM_ERROR',
        msg: '参数authorId错误',
      };
    }

    return author;
  }
}
