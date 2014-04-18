namespace UserInterface {
  partial class View {
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

    #region Component Designer generated code

    /// <summary> 
    /// Required method for Designer support - do not modify 
    /// the contents of this method with the code editor.
    /// </summary>
    public void InitializeComponent() {
      System.ComponentModel.ComponentResourceManager resources = new System.ComponentModel.ComponentResourceManager(typeof(View));
      this.headerStrip = new System.Windows.Forms.ToolStrip();
      this.headerTextLabel = new System.Windows.Forms.ToolStripLabel();
      this.closeItem = new System.Windows.Forms.ToolStripLabel();
      this.contentPanel = new System.Windows.Forms.Panel();
      this.grid = new System.Windows.Forms.DataGridView();
      this.footerStrip = new System.Windows.Forms.ToolStrip();
      this.imagePanel = new System.Windows.Forms.Panel();
      this.pictureBox = new System.Windows.Forms.PictureBox();
      this.title = new System.Windows.Forms.DataGridViewLinkColumn();
      this.headerStrip.SuspendLayout();
      this.contentPanel.SuspendLayout();
      ((System.ComponentModel.ISupportInitialize)(this.grid)).BeginInit();
      this.imagePanel.SuspendLayout();
      ((System.ComponentModel.ISupportInitialize)(this.pictureBox)).BeginInit();
      this.SuspendLayout();
      // 
      // headerStrip
      // 
      this.headerStrip.GripStyle = System.Windows.Forms.ToolStripGripStyle.Hidden;
      this.headerStrip.Items.AddRange(new System.Windows.Forms.ToolStripItem[] {
            this.headerTextLabel,
            this.closeItem});
      this.headerStrip.Location = new System.Drawing.Point(0, 0);
      this.headerStrip.Name = "headerStrip";
      this.headerStrip.Size = new System.Drawing.Size(324, 25);
      this.headerStrip.TabIndex = 0;
      this.headerStrip.Text = "headerStrip";
      // 
      // headerTextLabel
      // 
      this.headerTextLabel.Name = "headerTextLabel";
      this.headerTextLabel.Size = new System.Drawing.Size(37, 22);
      this.headerTextLabel.Text = "[Text]";
      // 
      // closeItem
      // 
      this.closeItem.Alignment = System.Windows.Forms.ToolStripItemAlignment.Right;
      this.closeItem.Image = ((System.Drawing.Image)(resources.GetObject("closeItem.Image")));
      this.closeItem.Name = "closeItem";
      this.closeItem.Size = new System.Drawing.Size(16, 22);
      // 
      // contentPanel
      // 
      this.contentPanel.Controls.Add(this.grid);
      this.contentPanel.Controls.Add(this.footerStrip);
      this.contentPanel.Controls.Add(this.imagePanel);
      this.contentPanel.Dock = System.Windows.Forms.DockStyle.Fill;
      this.contentPanel.Location = new System.Drawing.Point(0, 25);
      this.contentPanel.Name = "contentPanel";
      this.contentPanel.Size = new System.Drawing.Size(324, 240);
      this.contentPanel.TabIndex = 1;
      // 
      // grid
      // 
      this.grid.AllowUserToAddRows = false;
      this.grid.AllowUserToDeleteRows = false;
      this.grid.AllowUserToOrderColumns = true;
      this.grid.AllowUserToResizeColumns = false;
      this.grid.AllowUserToResizeRows = false;
      this.grid.CellBorderStyle = System.Windows.Forms.DataGridViewCellBorderStyle.None;
      this.grid.ColumnHeadersHeightSizeMode = System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode.AutoSize;
      this.grid.ColumnHeadersVisible = false;
      this.grid.Columns.AddRange(new System.Windows.Forms.DataGridViewColumn[] {
            this.title});
      this.grid.Dock = System.Windows.Forms.DockStyle.Fill;
      this.grid.Location = new System.Drawing.Point(0, 59);
      this.grid.Name = "grid";
      this.grid.RowHeadersVisible = false;
      this.grid.Size = new System.Drawing.Size(324, 156);
      this.grid.TabIndex = 2;
      // 
      // footerStrip
      // 
      this.footerStrip.BackColor = System.Drawing.Color.WhiteSmoke;
      this.footerStrip.Dock = System.Windows.Forms.DockStyle.Bottom;
      this.footerStrip.GripStyle = System.Windows.Forms.ToolStripGripStyle.Hidden;
      this.footerStrip.Location = new System.Drawing.Point(0, 215);
      this.footerStrip.Name = "footerStrip";
      this.footerStrip.Size = new System.Drawing.Size(324, 25);
      this.footerStrip.TabIndex = 1;
      this.footerStrip.Text = "footerStrip";
      // 
      // imagePanel
      // 
      this.imagePanel.AutoSize = true;
      this.imagePanel.AutoSizeMode = System.Windows.Forms.AutoSizeMode.GrowAndShrink;
      this.imagePanel.Controls.Add(this.pictureBox);
      this.imagePanel.Dock = System.Windows.Forms.DockStyle.Top;
      this.imagePanel.Location = new System.Drawing.Point(0, 0);
      this.imagePanel.Name = "imagePanel";
      this.imagePanel.Padding = new System.Windows.Forms.Padding(0, 0, 0, 3);
      this.imagePanel.Size = new System.Drawing.Size(324, 59);
      this.imagePanel.TabIndex = 0;
      // 
      // pictureBox
      // 
      this.pictureBox.Location = new System.Drawing.Point(3, 3);
      this.pictureBox.Name = "pictureBox";
      this.pictureBox.Size = new System.Drawing.Size(100, 50);
      this.pictureBox.SizeMode = System.Windows.Forms.PictureBoxSizeMode.AutoSize;
      this.pictureBox.TabIndex = 0;
      this.pictureBox.TabStop = false;
      // 
      // title
      // 
      this.title.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.Fill;
      this.title.DataPropertyName = "title";
      this.title.HeaderText = "title";
      this.title.Name = "title";
      this.title.ReadOnly = true;
      this.title.SortMode = System.Windows.Forms.DataGridViewColumnSortMode.Automatic;
      // 
      // View
      // 
      this.AutoScaleDimensions = new System.Drawing.SizeF(6F, 13F);
      this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
      this.Controls.Add(this.contentPanel);
      this.Controls.Add(this.headerStrip);
      this.Name = "View";
      this.Size = new System.Drawing.Size(324, 265);
      this.headerStrip.ResumeLayout(false);
      this.headerStrip.PerformLayout();
      this.contentPanel.ResumeLayout(false);
      this.contentPanel.PerformLayout();
      ((System.ComponentModel.ISupportInitialize)(this.grid)).EndInit();
      this.imagePanel.ResumeLayout(false);
      this.imagePanel.PerformLayout();
      ((System.ComponentModel.ISupportInitialize)(this.pictureBox)).EndInit();
      this.ResumeLayout(false);
      this.PerformLayout();

    }

    #endregion

    public System.Windows.Forms.ToolStrip headerStrip;
    public System.Windows.Forms.Panel contentPanel;
    public System.Windows.Forms.Panel imagePanel;
    public System.Windows.Forms.ToolStrip footerStrip;
    public System.Windows.Forms.PictureBox pictureBox;
    public System.Windows.Forms.DataGridView grid;
    private System.Windows.Forms.ToolStripLabel headerTextLabel;
    private System.Windows.Forms.ToolStripLabel closeItem;
    private System.Windows.Forms.DataGridViewLinkColumn title;
  }
}
