/// <reference path="common.ts"/>
let editor_scroll = 0
let view_scroll = 0
let editArticle = (ev: MouseEvent) => {
    ev.stopPropagation()
    preview = !preview
    let text = document.getElementById('text')!
    let index = document.getElementById('article-index')!
    if (preview) {
        let editor = document.getElementById('editor')
        if (editor) editor_scroll = editor.scrollTop
        index.style.display = ''
        content = (text.firstElementChild! as HTMLInputElement).value
        text.innerHTML = convertMarkdown(content)
        hljs.highlightAll()
        generateIndex()
        scrollTo(0, view_scroll)
    } else {
        view_scroll = document.body.scrollTop
        dirty = true
        document.getElementById('save')!.innerText = 'Save'
        index.style.display = 'none'
        let input = DOMFromStr('<textarea type="text" id="editor"></textarea>') as HTMLTextAreaElement
        input.value = content
        text.innerHTML = ''
        text.appendChild(input)
        input.scrollBy(0, editor_scroll)
    }


}
const base = "/admin"
const route = (event) => {
    
    let href = getTargetA(event).getAttribute('href')
    event = event || window.event;
    event.preventDefault();
    window.history.pushState({}, "", base + "/" + href);
    handleLocation()

};

// const routes = {
//     404: "/pages/404.html",
//     "/": "/pages/index.html",
//     "/about": "/pages/about.html",
//     "/lorem": "/pages/lorem.html",
// };
let content = ""

const handleLocation = async () => {
    console.log("handle location")
    if (window.location.pathname.slice(-1) === "/") {
        window.location.pathname = window.location.pathname.slice(0, -1)
        return
    }
    const path_ = window.location.pathname
    const path = path_.slice(base.length)


    const paths = path.split('/').slice(1)
    console.log(path, paths)
    
    if (path.length === 0) {
        window.location.pathname += "/article"
        return

    }
    if (paths.length === 1 && paths[0] == "article") {
        dirty = false
        return await listArticle(true)
    }
    if (paths.length === 2 && paths[0] === "article" && parseInt(paths[1]) >= 0) {
        let article_id = parseInt(paths[1])
        return loadArticle(article_id, (res: Post, id: string | number) => {
            content = res.content!
            let article_cont = getArticlesContainer()
            let switch_s =         
            `        
            <label class="switch">
                <input type="checkbox">
                <span class="slider"  id="edit-switch"></span>
            </label>`
            let save_s = `<button id='save'>Save</button>`
            
            article_cont.appendChild(DOMFromStr(switch_s))
            article_cont.appendChild(DOMFromStr(save_s))
        
            let sw = document.getElementById('edit-switch')!
            sw.onclick = editArticle
            let save = document.getElementById('save')!
            save.onclick = async (ev) => {
                content = (document.getElementById('editor')! as HTMLTextAreaElement).value
                let response = await fetch(`/post/${id}`, {
                    method: "PUT",
                    body: JSON.stringify({
                        content: content
                    })
                })
                if (response.status !== 200) {
                    console.warn("Cannot Save")
                } else {
                    save.innerText = "Saved!"
                }
            }
        })

    } else if (paths.length === 2 && paths[0] === "image" && parseInt(paths[1]) >= 0) {
        let article_id = parseInt(paths[1])
        return listImage(article_id)
    } 
    else {
        load404()
    }
}

async function listImage(id: string | number) {
    console.log("list image")
    let images = await (await fetch(`/image/${id}`)).json() as [string]
    console.log(images)
    let menu = getMenu()
    menu.style.display = 'none'
    let article_cont = document.getElementById("articles-container")!
    let image_list = document.createElement("div") as HTMLDivElement
    images.forEach((img) => {
        let img_div = document.createElement("div") as HTMLDivElement
        img_div.innerText = img
        image_list.append(img_div)
    })
    article_cont.appendChild(image_list)
}

window.onpopstate = handleLocation;
window.onload = () => handleLocation();



