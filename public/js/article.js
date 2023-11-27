
function timeConverter(UNIX_timestamp){
    var a = new Date(UNIX_timestamp * 1000);
    var months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    var year = a.getFullYear();
    var month = months[a.getMonth()];
    var date = a.getDate();
    var hour = a.getHours();
    var min = a.getMinutes();
    var sec = a.getSeconds();
    var time = date + ' ' + month + ' ' + year + ' ' + hour + ':' + min + ':' + sec ;
    return time;
}
let previous_scroll = 0
let listArticle = async () => {
    // window.scrollTo(0, previous_scroll)
    let article_cont = document.getElementById("articles-container")
    article_cont.innerHTML = '';
    let post_meta = await fetch("post").then((res) => res.json())

    let row = document.createElement("div")
    row.className = "article-row"
    post_meta.forEach((element, i) => {
        if (i !== 0 && i % 2 === 0) {
            article_cont.appendChild(row)
            row = document.createElement("div")
            row.className = "article-row"
        }
        const s = `        
        <a class="article-col" href="article/${element.id}">
            <h2 class="article-cover" style="background-image: url('image/showcase.png');" article_id="${element.id}">
                <div class="article-desc">
                    ${element.title}
                </div>
            </h2>
        </a>`
        let article_col = DOMFromStr(s)

        article_col.addEventListener('click', route)
        row.appendChild(article_col)
    });
}
let indexScroll = (ev) => {
    let index = document.getElementById('article-index')
    let article_cont = document.getElementById("articles-container")
    if (index === null) return;
    let pad_str = window.getComputedStyle(article_cont, null).getPropertyValue('padding-top')
    let pad = parseFloat(pad_str.slice(0, pad_str.length - 2))
    // console.log(document.documentElement.scrollTop, article_cont.offsetTop)

    if (document.documentElement.scrollTop < article_cont.offsetTop) {
        index.style.top = `${article_cont.offsetTop - document.documentElement.scrollTop + pad}px`
    } else {
        index.style.top = pad_str
    }
}
let loadArticle = async (id) => {
    const path = `post/${id}`;
    let article = await (await fetch(`/post/${id}`)).json()
    let res = article;
    let article_cont = document.getElementById("articles-container")
    window.scroll(5, 0)
    indexScroll()   
    window.onscroll = indexScroll
    let s =         
    `        
    <div id="article-index"></div>
    <div id="article-content">
        <h1 id="article-title">${res.title}</h1>
        <div>views: ${res.views}</div>
        <div>created: ${timeConverter(res.created_time)}, last modified: ${timeConverter(res.modified_time)}</div>
        <br></br>
        ${res.content}
    </div>`
    article_cont.innerHTML = s.trim()
    let index = document.getElementById("article-index")
    let article_content = document.getElementById('article-content')
    let title = document.getElementById('article-title')
    console.log(title)
    let title_clone = document.createElement('a')
    title_clone.innerHTML = title.innerHTML
    index.append(title_clone)
    title_clone.href = `#article-title`
    let h3s = article_content.getElementsByTagName('H3')
    for (let h3 of h3s) {
        h3.id = h3.innerHTML;
        let a = document.createElement('a')
        a.innerHTML = h3.innerHTML
        a.href = `#${a.innerHTML}`
        index.appendChild(a)
    }
    window.scrollTo(0, article_cont.offsetTop)
    

}
const route = (event) => {
    // console.log(event.target)
    
    let href = getTargetA(event).getAttribute('href')
    event = event || window.event;
    event.preventDefault();
    window.history.pushState({}, "", href);
    handleLocation()

};

// const routes = {
//     404: "/pages/404.html",
//     "/": "/pages/index.html",
//     "/about": "/pages/about.html",
//     "/lorem": "/pages/lorem.html",
// };

const handleLocation = async () => {
    const path = window.location.pathname;
    if (path === "/") return await listArticle()
    let article_id = (/^\/article\/(\d+)$/.exec(path) || [-1,-1])[1]
    if (article_id > 0) {return loadArticle(article_id)}
}

window.onpopstate = handleLocation;
window.route = route;

// window.onload = async () => {
//     listArticle()
// }
window.onload = handleLocation();

function getTargetA(ev) {
    return ev.target.tagName == 'H2' ? ev.target.parentElement : ev.target.parentElement.parentElement
}

function DOMFromStr(s) {
    let d = document.createElement("div")
    d.innerHTML = s.trim()
    return d.firstChild;
}