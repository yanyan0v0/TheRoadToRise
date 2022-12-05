import { Controller } from 'egg';
import fs from 'fs';
import AUTHOR_LIST from '../assets/book/author.json';
import BOOK_LIST from '../assets/book/book.json';
import CHAPTER_LIST from '../assets/book/chapter.json';

export default class ChapterController extends Controller {
  public async getChapterListByBookId() {
    const { bookId } = this.ctx.params;

    if (!Number(bookId)) {
      this.ctx.error('PARAM_ERROR', '参数bookId错误');
      return;
    }

    const chapterList = CHAPTER_LIST.filter(
      item => item.bookId === Number(bookId),
    );
    this.ctx.success('获取章节列表成功', chapterList);
  }

  public async getChapterById() {
    const { chapterId } = this.ctx.params;
    if (!Number(chapterId)) {
      this.ctx.error('PARAM_ERROR', '参数chapterId错误');
      return;
    }
    const chapter = CHAPTER_LIST.find(item => item.id === Number(chapterId));
    if (!chapter) {
      this.ctx.error('PARAM_ERROR', '参数chapterId错误');
      return;
    }
    const book = BOOK_LIST.find(item => item.id === chapter.bookId);
    if (!book) {
      this.ctx.error('PARAM_ERROR', '参数chapterId错误');
      return;
    }
    const author = AUTHOR_LIST.find(item => item.id === book.authorId);
    if (!author) {
      this.ctx.error('PARAM_ERROR', '参数chapterId错误');
      return;
    }

    const res = fs.readFileSync(chapter.file);
    let txtString = res.toString();
    txtString = txtString.replace(/\n/g, '</p><p>');
    txtString = `<p>${txtString}</p>`;

    const response = {
      ...chapter,
      bookName: book.name,
      authorName: author.name,
      txtString,
    };
    this.ctx.success('获取章节成功', response);
  }
}
