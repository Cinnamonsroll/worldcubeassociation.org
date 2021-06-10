$(function() {
    $(".char-counter").each(function() {
            let maxLength = $(this).attr("maxlength"),
                commentLength = document.createElement("p");
            if (!maxLength) return
            commentLength.style.float = "right";
            $(this).parent("div").append(commentLength);
            $(this).on("input", function() {
                commentLength.innerText = this.value.length + "/" + maxLength;
            }).trigger("input");
        }
    });
});
