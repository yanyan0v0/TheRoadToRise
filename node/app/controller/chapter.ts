import { Controller } from 'egg';
import fs from 'fs';

export default class ChapterController extends Controller {
  public async getChapterListByBookId() {
    const { bookId } = this.ctx.params;

    try {
      const chapterList = await this.ctx.service.chapter.getChapterListByBookId(Number(bookId));
      this.ctx.success('获取章节列表成功', chapterList);
    } catch (error) {
      this.ctx.error(error);
    }
  }

  public async getChapterById() {
    const { bookId, chapterId } = this.ctx.params;

    try {
      const chapter = await this.ctx.service.chapter.getChapterById(Number(bookId), Number(chapterId));
      console.log(1, chapter);
      const book = await this.ctx.service.book.getBookById(Number(bookId));
      console.log(2, book);
      const author = await this.ctx.service.author.getAuthorById(Number(book.authorId));
      console.log(3, author);

      const res = fs.readFileSync(chapter.file as string);
      let txtString = res.toString();
      console.log(4, txtString);
      txtString = txtString.replace(/\n/g, '</p><p>');
      txtString = `<p>${txtString}</p>`;

      const response = {
        ...chapter,
        bookName: book.name,
        authorName: author.name,
        txtString,
      };
      this.ctx.success('获取章节详情成功', response);
    } catch (error) {
      this.ctx.error(error);
    }
  }
}
