import unittest

from review_samples import FALLBACK_COMMENTS, MOVIE_COMMENTS, REVIEWER_NAMES, review_comment


class ReviewSamplesTests(unittest.TestCase):
    def test_names_and_movie_comments_are_complete(self):
        self.assertEqual(len(set(REVIEWER_NAMES)), 10)
        for comments in [*MOVIE_COMMENTS.values(), FALLBACK_COMMENTS]:
            self.assertEqual(len(comments), 5)
            for variants in comments:
                self.assertEqual(len(set(variants)), 2)
                for comment in variants:
                    self.assertTrue(0 < len(comment) <= 1000)
                    self.assertNotIn('[Demo]', comment)

    def test_score_variants_and_title_matching(self):
        for title in MOVIE_COMMENTS:
            for rating in range(1, 6):
                self.assertEqual(review_comment(title.upper(), rating), MOVIE_COMMENTS[title][rating - 1][0])
                self.assertEqual(review_comment(title, rating, 1), MOVIE_COMMENTS[title][rating - 1][1])
        self.assertEqual(review_comment('New movie', 5), FALLBACK_COMMENTS[4][0])
        with self.assertRaises(ValueError):
            review_comment('Inception', 6)

    def test_customer_reviews_do_not_repeat_within_a_movie(self):
        for title in MOVIE_COMMENTS:
            for rating in range(1, 6):
                comments = [review_comment(title, rating, customer) for customer in range(11)]
                self.assertEqual(len(set(comments)), 11, (title, rating))
                self.assertTrue(all(len(comment) <= 1000 for comment in comments))


if __name__ == '__main__':
    unittest.main()
