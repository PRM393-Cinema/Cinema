"""Fictional names and Vietnamese opinions for the opt-in local review seed."""

REVIEWER_NAMES = (
    "Nguyễn Minh Anh", "Trần Hoàng Nam", "Lê Thu Hà", "Phạm Quốc Huy",
    "Võ Ngọc Linh", "Đặng Gia Bảo", "Bùi Khánh Vy", "Đỗ Tuấn Kiệt",
    "Hoàng Phương Thảo", "Ngô Đức Thành",
)

# Each movie has two comments for each rating, from one to five stars.
MOVIE_COMMENTS = {
    "Chuyến Tàu Sinh Tử": (
        ("Không hợp gu mình, xem cảnh nào cũng căng thẳng nên khá mệt.", "Mình thích phim zombie nhiều hành động hơn, đoạn gia đình làm mình thấy dài."),
        ("Bối cảnh trên tàu khá hay nhưng vài quyết định của nhân vật khó hiểu quá.", "Có mấy cảnh chạy trốn cuốn, tiếc là cách xử lý tình huống hơi gượng."),
        ("Xem giải trí ổn, đoạn cuối cảm động hơn mình tưởng.", "Không quá bất ngờ về câu chuyện, nhưng không khí trên tàu làm khá tốt."),
        ("Nhịp phim nhanh, không gian chật trên tàu làm các cảnh rượt đuổi rất hồi hộp.", "Thích cách phim kể chuyện cha con giữa cảnh hỗn loạn, xem xong vẫn nhớ đoạn cuối."),
        ("Vừa hồi hộp vừa xúc động. Lâu rồi mới xem một phim zombie khiến mình quan tâm nhân vật đến vậy.", "Đi xem vì zombie mà cuối cùng lại khóc vì chuyện gia đình. Rất đáng xem."),
    ),
    "Kẻ Hủy Diệt Thời Gian": (
        ("Các mốc thời gian làm mình rối, xem hết vẫn không thấy thuyết phục.", "Kỹ xảo không cứu được câu chuyện, mình không kết nối được với nhân vật."),
        ("Có vài cảnh hành động ổn nhưng phần giải thích du hành thời gian hơi vòng vèo.", "Mình mong phim giữ được không khí căng thẳng hơn, nhiều đoạn đùa làm mất hứng."),
        ("Hành động xem được, nội dung thì nên xem kỹ kẻo lẫn các mốc thời gian.", "Phù hợp để giải trí cuối tuần, nhưng không phải phần mình thích nhất."),
        ("Mấy cảnh rượt đuổi khá đã, thích cảm giác quen thuộc của nhân vật Kẻ Hủy Diệt.", "Xem vì hành động nên khá hài lòng, không đặt nặng chuyện các nhánh thời gian."),
        ("Mình thích kiểu hành động dồn dập này, xem một mạch không thấy chán.", "Những màn đối đầu giữa người và máy rất cuốn. Fan hành động như mình xem thấy đã."),
    ),
    "Thiên Đường Máu": (
        ("Câu chuyện nặng nề nhưng cách kể chưa làm mình tin vào nhân vật.", "Không hợp cách xây dựng cao trào của phim, xem xong thấy khá hụt hẫng."),
        ("Chủ đề đáng quan tâm, tiếc là vài đoạn thoại giải thích nhiều quá.", "Không khí căng nhưng nhịp kể lúc nhanh lúc chậm, mình hơi khó theo cảm xúc."),
        ("Có những cảnh khiến mình suy nghĩ, dù cách xử lý một vài tình huống còn dễ đoán.", "Nội dung có điều để bàn sau khi xem, phần dẫn dắt thì mình thấy chỉ ở mức ổn."),
        ("Không khí ngột ngạt được giữ khá tốt, xem xong vẫn còn nghĩ về lựa chọn của nhân vật.", "Thích cách phim đặt nhân vật vào tình thế khó, càng về cuối càng thấy nặng lòng."),
        ("Phim làm mình căng thẳng từ đầu đến cuối. Câu chuyện ám ảnh hơn mình dự đoán.", "Xem xong im một lúc mới muốn nói chuyện. Với mình đây là một trải nghiệm rất đáng nhớ."),
    ),
    "Ma Xó": (
        ("Mình không hợp kiểu hù dọa này, âm thanh lớn nhiều hơn cảm giác sợ.", "Chờ một câu chuyện thuyết phục hơn, xem xong vẫn thấy nhiều tình huống gượng."),
        ("Bối cảnh có nét riêng nhưng vài đoạn chuyển cảnh làm mình mất mạch.", "Có cảnh tạo không khí tốt, tiếc là phần giải thích phía sau chưa tới."),
        ("Xem với bạn bè cũng ổn, một vài cảnh khiến cả nhóm giật mình.", "Không khí tâm linh khá thú vị, nhưng nhịp phim có đoạn hơi chùng."),
        ("Mình thích phần bối cảnh và không khí bí bách, không cần hù liên tục vẫn thấy bất an.", "Đi xem buổi tối nên mấy cảnh im lặng còn đáng sợ hơn tiếng động lớn."),
        ("Thích cách phim dùng không gian và âm thanh để tạo cảm giác bất an. Xem xong vẫn hơi lạnh gáy.", "Lâu rồi mới có phim kinh dị Việt làm mình phải nhìn quanh lúc về nhà."),
    ),
    "Bố Già": (
        ("Không hợp gu mình, nhiều cảnh cãi vã làm cảm xúc bị quá tải.", "Mình thấy phim cố đẩy nước mắt hơi nhiều, nên đoạn cuối lại khó xúc động."),
        ("Diễn xuất có điểm sáng nhưng vài đoạn thoại dài quá, xem hơi mệt.", "Chuyện gia đình gần gũi, tiếc là nhịp kể và tiếng ồn làm mình khó nhập tâm."),
        ("Có cảnh rất thương người cha, có cảnh lại hơi làm quá. Nhìn chung xem được.", "Thích không khí xóm nhỏ và những chi tiết đời thường hơn các đoạn cao trào."),
        ("Cách ba con hiểu lầm nhau khá gần với nhiều gia đình. Mình thích những đoạn nói chuyện nhỏ nhẹ nhất.", "Xem cùng mẹ, ra về hai mẹ con còn bàn về cách nhân vật thể hiện tình thương."),
        ("Mấy cảnh cha con làm mình nhớ ba. Phim có chỗ ồn nhưng cảm xúc đọng lại rất lâu.", "Không ngờ một câu chuyện xóm lao động lại khiến mình khóc nhiều vậy. Muốn gọi về nhà ngay sau khi xem."),
    ),
    "Doraemon: Đi Du Lịch Việt Nam": (
        ("Mình mong có một chuyến phiêu lưu hấp dẫn hơn, các đoạn giới thiệu hơi dài.", "Câu chuyện lần này chưa cuốn với mình, thấy giống đi tham quan hơn là một cuộc phiêu lưu."),
        ("Có nhiều cảnh dễ thương nhưng phần nối giữa các địa điểm hơi rời rạc.", "Các bé thích nhân vật, còn mình thấy câu chuyện thiếu một điểm nhấn rõ hơn."),
        ("Xem nhẹ nhàng với gia đình thì ổn, thích những chi tiết về món ăn Việt.", "Không quá kịch tính nhưng hình ảnh vui mắt, hợp cho một buổi xem cùng các bé."),
        ("Thấy Doraemon và Nobita khám phá Việt Nam vui thật, nhất là những đoạn giới thiệu đồ ăn.", "Mình thích cảm giác quen thuộc khi các nhân vật đến những địa danh Việt Nam."),
        ("Vừa có tuổi thơ Doraemon vừa có những hình ảnh Việt Nam gần gũi. Cả nhà xem rất vui.", "Bé nhà mình thích mê, xem xong còn hỏi thêm về các địa điểm trong phim."),
    ),
    "Dune: Hành Tinh Cát": (
        ("Quá chậm với mình, xem hết mà cảm giác câu chuyện mới bắt đầu.", "Hình ảnh đẹp nhưng nhân vật và thế giới của phim không làm mình muốn theo tiếp."),
        ("Phải nhớ nhiều tên và gia tộc quá, mình chưa đọc truyện nên hơi đuối.", "Thích cảnh sa mạc, nhưng những đoạn đối thoại dài khiến mình mất tập trung."),
        ("Phần nhìn và âm thanh rất tốt, nội dung cần kiên nhẫn hơn mình nghĩ.", "Một phần mở đầu ổn, nhưng ai chờ một câu chuyện trọn vẹn có thể thấy hụt."),
        ("Cảnh sa mạc và cảm giác đồ sộ của Arrakis quá hợp màn ảnh lớn.", "Nhịp chậm nhưng có chủ đích, mình thích cách các gia tộc và quyền lực được giới thiệu."),
        ("Âm thanh, hình ảnh và bầu không khí ăn khớp với nhau. Xem ở rạp mới cảm hết độ lớn của thế giới này.", "Mình mê cách phim xây dựng Arrakis, vừa đẹp vừa có cảm giác khắc nghiệt. Muốn xem tiếp ngay."),
    ),
    "Interstellar": (
        ("Không hợp cách kể pha nhiều giải thích khoa học, mình thấy phim dài và khó vào.", "Phần tình cảm không chạm được tới mình nên đoạn cuối xem khá xa lạ."),
        ("Hình ảnh không gian đẹp nhưng nhiều đoạn giải thích làm mình mệt.", "Mình thích hành trình khám phá hơn phần giải quyết ở cuối, hơi hụt kỳ vọng."),
        ("Nhạc và hình ảnh rất đáng xem, có vài đoạn mình cần về đọc thêm mới hiểu.", "Cảm xúc cha con tốt, còn những ý tưởng khoa học thì không phải đoạn nào mình cũng theo kịp."),
        ("Cảnh trên hành tinh nước căng thật. Nhạc của phim nghe ở rạp rất ấn tượng.", "Thích cách phim nối chuyến đi trong không gian với nỗi nhớ gia đình, dù hơi dài."),
        ("Đoạn xem tin nhắn của các con làm mình nghẹn. Xem lại vẫn nổi da gà vì nhạc và cảm xúc.", "Một trong những phim khiến mình muốn ngồi lại đến hết nhạc cuối. Vừa choáng ngợp vừa rất con người."),
    ),
    "Inception": (
        ("Các lớp giấc mơ làm mình rối, đến cuối vẫn không thấy hào hứng.", "Mình thấy phần giải thích luật quá nhiều, khó quan tâm đến cảm xúc nhân vật."),
        ("Ý tưởng hay nhưng cách kể hơi lạnh, mình không kết nối được với Cobb.", "Có cảnh hành động sáng tạo nhưng phải nhớ luật liên tục nên xem hơi căng."),
        ("Hành lang xoay rất ấn tượng. Câu chuyện cần tập trung, không phải kiểu phim xem cho nhẹ đầu.", "Xem giải trí tốt nếu thích giải đố, nhưng mình vẫn muốn phần nhân vật được kể sâu hơn."),
        ("Thích cách các tầng mơ ảnh hưởng lẫn nhau, nhất là khi mọi thứ được cắt dựng song song.", "Xem xong còn tranh luận về con quay với bạn. Nhịp phim và phần nhạc rất cuốn."),
        ("Ý tưởng giấc mơ được biến thành những cảnh hành động quá sáng tạo. Xem lại vẫn tìm được chi tiết mới.", "Từ cảnh hành lang đến đoạn kết đều khiến mình nhớ lâu. Một phim mình sẵn sàng xem lại nhiều lần."),
    ),
    "Avengers: Endgame": (
        ("Không theo hết các phần trước nên mình thấy phim dài và nhiều đoạn khó cảm.", "Mình không thích cách giải quyết bằng các mốc thời gian, cảm xúc cũng không cứu được với mình."),
        ("Đoạn cuối hoành tráng nhưng phần giữa chậm hơn mình chờ đợi.", "Có những màn gặp lại nhân vật vui, còn câu chuyện thì mình thấy khá tiện tay."),
        ("Một cái kết nhiều cảm xúc cho người theo lâu năm, dù có vài chỗ mình chưa thấy hợp lý.", "Đi cùng nhóm bạn fan Marvel nên không khí rất vui. Phần kịch bản thì mình thấy ở mức ổn."),
        ("Những màn gặp lại và chia tay nhân vật được làm khá tình cảm, đoạn chiến đấu cuối rất đã.", "Theo các nhân vật nhiều năm nên xem phần này thấy vừa vui vừa tiếc."),
        ("Chờ bao lâu mới được nghe câu tập hợp ấy ở rạp. Đoạn cuối làm mình nổi da gà.", "Một lời chia tay nhiều cảm xúc với những nhân vật mình đã theo từ hồi đi học."),
    ),
    "Spider-Man: No Way Home": (
        ("Mình chưa thấy câu chuyện đứng vững nếu bỏ những màn gợi nhớ các phần cũ.", "Các quyết định của nhân vật khiến mình khó chịu hơn là thương, xem hơi hụt hẫng."),
        ("Màn xuất hiện của các nhân vật quen vui thật, nhưng phần mở nút hơi gượng.", "Thích vài cảnh hành động, còn cách xử lý chuyện đa vũ trụ thì mình chưa bị thuyết phục."),
        ("Xem vui và nhiều bất ngờ, chỉ là câu chuyện có chỗ dựa vào cảm xúc hoài niệm quá nhiều.", "Một phim Người Nhện dễ xem, đoạn cuối có sức nặng hơn mình tưởng."),
        ("Thích cách Peter phải chịu trách nhiệm với lựa chọn của mình, không chỉ có những màn gặp lại.", "Đi xem cùng bạn thân, cả hai cứ nhìn nhau khi những nhân vật quen xuất hiện."),
        ("Xem Người Nhện từ nhỏ nên những màn hội ngộ làm mình vui không tả được. Đoạn kết lại buồn thật.", "Vừa được sống lại ký ức các phần cũ vừa thấy Peter trưởng thành hơn. Rất đáng một vé rạp."),
    ),
    "Oppenheimer": (
        ("Phim nói quá nhiều và đổi mốc thời gian liên tục, mình xem không vào.", "Mình biết đây là phim tiểu sử, nhưng nhịp kể vẫn quá nặng với mình."),
        ("Diễn viên tốt nhưng tuyến điều trần kéo dài làm mình mất tập trung.", "Âm thanh ấn tượng, tiếc là quá nhiều nhân vật khiến mình khó theo các mối quan hệ."),
        ("Nhiều cảnh diễn rất tốt, nhưng cần tập trung và có chút kiến thức bối cảnh mới xem thoải mái.", "Mình thích phần chuẩn bị thử nghiệm hơn những cuộc đối thoại chính trị phía sau."),
        ("Cillian Murphy diễn bằng ánh mắt rất hay. Phần sau vụ thử còn ám ảnh hơn chính vụ nổ.", "Cách dùng khoảng lặng và âm thanh làm cảnh thử nghiệm cực kỳ căng, dù phim hơi dài."),
        ("Xem xong vẫn nghĩ về cái giá của một thành tựu. Diễn xuất và âm thanh làm mình bị cuốn suốt phim.", "Đây là phim về trách nhiệm và sự day dứt với mình. Đoạn kết khiến cả câu chuyện nặng thêm rất nhiều."),
    ),
    "Mưa đỏ": (
        ("Mình không hợp cách đẩy cảm xúc ở vài cảnh, thấy hơi quá tay.", "Câu chuyện chưa giúp mình gắn bó đủ với từng nhân vật trước các mất mát."),
        ("Có những hình ảnh ấn tượng nhưng lời thoại ở vài đoạn làm mình khó nhập tâm.", "Đề tài đáng trân trọng, còn nhịp chuyển giữa các cảnh mình thấy chưa thật đều."),
        ("Có cảnh rất xúc động, nhưng mình muốn phim dành thêm thời gian cho đời sống của nhân vật.", "Xem xong có nhiều điều để suy nghĩ, dù cách kể có đoạn vẫn hơi dễ đoán."),
        ("Những khoảnh khắc đồng đội chăm sóc nhau làm mình nhớ hơn cả các cảnh chiến đấu.", "Không khí khốc liệt được thể hiện rõ, nhiều đoạn xem thấy nặng lòng."),
        ("Ra khỏi rạp vẫn còn lặng người. Câu chuyện về những người lính trẻ khiến mình rất xúc động.", "Thích cách phim để lại cảm giác thương con người giữa chiến tranh. Muốn xem lại cùng gia đình."),
    ),
}

FALLBACK_COMMENTS = (
    ("Mình xem không vào, câu chuyện không hợp gu.", "Mình chờ đợi nhiều hơn, xem xong thấy khá hụt hẫng."),
    ("Có vài cảnh ổn nhưng nhịp kể chưa cuốn mình.", "Ý tưởng có nét riêng, tiếc là cách dẫn dắt chưa thuyết phục."),
    ("Xem giải trí ổn, nhưng chưa có cảnh nào làm mình nhớ lâu.", "Có điểm mình thích, cũng có đoạn hơi chùng. Nhìn chung ở mức vừa phải."),
    ("Diễn xuất tốt và câu chuyện dễ theo, mình thấy đáng đi xem.", "Xem xong vẫn muốn bàn thêm với bạn về các nhân vật."),
    ("Cảm xúc đọng lại rất lâu sau khi ra rạp, mình muốn xem thêm lần nữa.", "Một buổi xem phim rất đáng nhớ với mình, từ câu chuyện đến cách thể hiện."),
)

RATING_NOTES = (
    ("Chắc mình sẽ không xem lại.", "Đây không phải kiểu phim mình muốn giới thiệu cho bạn bè.",
     "Với mình, trải nghiệm lần này không đáng như mong đợi.", "Ra về mình vẫn thấy tiếc kỳ vọng ban đầu.", "Lần sau mình sẽ cân nhắc kỹ hơn trước khi mua vé."),
    ("Mình vẫn muốn phần kể chuyện được làm kỹ hơn.", "Có lẽ mình đã đặt kỳ vọng hơi cao.",
     "Mình chưa thấy đủ cuốn để xem lần nữa.", "Đi xem cùng bạn thì vui, còn riêng phim mình chưa hài lòng.", "Hy vọng lần sau sẽ có cách dẫn dắt tốt hơn."),
    ("Với mình, một lần xem là vừa đủ.", "Có điểm thú vị, nhưng cũng có phần mình chưa thích.",
     "Bạn đi cùng mình thích hơn mình một chút.", "Không tiếc tiền vé nhưng cũng chưa muốn xem lại ngay.", "Nếu thích thể loại này thì vẫn có thể thử."),
    ("Mình thấy một vé rạp như vậy là xứng đáng.", "Có dịp mình sẽ rủ bạn xem cùng.",
     "Chưa hoàn hảo nhưng cảm giác sau buổi xem khá tốt.", "Ra về mình vẫn còn bàn về phim với bạn.", "Mình sẽ giới thiệu cho người có cùng gu."),
    ("Mình sẵn sàng mua vé xem thêm lần nữa.", "Rất vui vì đã chọn xem phim này ở rạp.",
     "Đây là một buổi xem phim mình sẽ còn nhớ lâu.", "Mình đã rủ thêm bạn đi xem sau buổi này.", "Xem xong chỉ muốn tìm người để nói thêm về phim."),
)


def review_comment(title, rating, variant=0):
    if rating not in range(1, 6):
        raise ValueError("Rating must be from 1 to 5")
    comments = next((value for key, value in MOVIE_COMMENTS.items()
                     if key.casefold() == title.casefold()), FALLBACK_COMMENTS)
    options = comments[rating - 1]
    comment = options[variant % len(options)]
    if variant >= len(options):
        notes = RATING_NOTES[rating - 1]
        comment += " " + notes[(variant // len(options) - 1) % len(notes)]
    return comment
