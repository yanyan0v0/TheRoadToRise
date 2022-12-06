import { Controller } from 'egg';

export default class BookController extends Controller {
  public async getBookById() {
    const { bookId } = this.ctx.params;

    try {
      const book = await this.ctx.service.book.getBookById(Number(bookId));
      this.ctx.success('获取书籍详情成功', book);
    } catch (error) {
      this.ctx.error(error);
    }
  }
}
