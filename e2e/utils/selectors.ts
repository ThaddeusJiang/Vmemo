// 选择器定义
export const selectors = {
  // 认证相关
  login: {
    emailInput: 'input[name="user[email]"]',
    passwordInput: 'input[name="user[password]"]',
    submitButton: 'button:has-text("Sign in")',
  },

  // 照片上传相关
  upload: {
    form: '#upload-form',
    fileInput: 'input[type="file"]',
    fileLabel: 'label[for*="photos"]',
    noteTextarea: 'textarea[name="note"]',
    submitButton: 'button[type="submit"]',
    progressBar: '[data-phx-hook="Phoenix.LiveFileUpload"] .phx-file-upload-progress',
    dropTarget: '[phx-drop-target]',
  },

  // 照片列表相关
  photoList: {
    container: '[data-phx-hook="Waterfall"]',
    photoCard: '.photo-card',
    loadMoreButton: 'button:has-text("Load More")',
    searchInput: 'input[name="q"]',
  },

  // 照片详情相关
  photoDetail: {
    image: 'img[alt*="测试照片"]',
    deleteButton: 'button[aria-label="delete"]',
    expandButton: 'button[aria-label="expand"]',
    editForm: 'form',
    noteTextarea: 'textarea[name="note"]',
    saveButton: 'button:has-text("Save")',
    aiButton: 'button[aria-label="AI trained"]',
  },

  // 通用元素
  common: {
    flashMessage: '.flash',
    modal: '.modal',
    confirmButton: 'button:has-text("Yes")',
  },
};

// 测试数据
export const testData = {
  testImage1: 'fixtures/test-image-1.png',
  testImage2: 'fixtures/test-image-2.png',
  testNote: '测试照片备注',
  updatedNote: '更新后的备注内容',
};

// 页面 URL
export const urls = {
  login: '/users/log_in',
  home: '/home',
  photos: '/photos',
  upload: '/upload',
  photoDetail: (id: string) => `/photos/${id}`,
  photoEdit: (id: string) => `/photos/${id}?action=edit`,
};
