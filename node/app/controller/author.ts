import { Controller } from 'egg';

export default class AuthorController extends Controller {
  public async getAuthorByBookId() {
    const { bookId } = this.ctx.params;

    try {
      const book = await this.ctx.service.book.getBookById(Number(bookId));
      const author = await this.ctx.service.author.getAuthorById(book.authorId as number);
      this.ctx.success('获取作者详情成功', author);
    } catch (error) {
      this.ctx.error(error);
    }
  }
}
