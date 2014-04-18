namespace UserInterface {
  partial class Browser {
    /// <summary>
    /// Required designer variable.
    /// </summary>
    public System.ComponentModel.IContainer components = null;

    /// <summary>
    /// Clean up any resources being used.
    /// </summary>
    /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
    protected override void Dispose(bool disposing) {
      if (disposing && (components != null)) {
        components.Dispose();
      }
      base.Dispose(disposing);
    }

    #region Windows Form Designer generated code

    /// <summary>
    /// Required method for Designer support - do not modify
    /// the contents of this method with the code editor.
    /// </summary>
    public void InitializeComponent() {
      this.browserControl = new System.Windows.Forms.WebBrowser();
      this.SuspendLayout();
      // 
      // browserControl
      // 
      this.browserControl.Dock = System.Windows.Forms.DockStyle.Fill;
      this.browserControl.Location = new System.Drawing.Point(0, 0);
      this.browserControl.MinimumSize = new System.Drawing.Size(20, 20);
      this.browserControl.Name = "browserControl";
      this.browserControl.Size = new System.Drawing.Size(292, 266);
      this.browserControl.TabIndex = 0;
      // 
      // Browser
      // 
      this.AutoScaleDimensions = new System.Drawing.SizeF(6F, 13F);
      this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
      this.ClientSize = new System.Drawing.Size(292, 266);
      this.Controls.Add(this.browserControl);
      this.Name = "Browser";
      this.Text = "Browser";
      this.ResumeLayout(false);

    }

    #endregion

    public System.Windows.Forms.WebBrowser browserControl;
  }
}