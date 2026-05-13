-- CreateEnum
CREATE TYPE "Plan" AS ENUM ('FREE', 'PREMIUM', 'FAMILY');

-- CreateEnum
CREATE TYPE "WorkspaceMemberRole" AS ENUM ('OWNER', 'ADMIN', 'MEMBER', 'VIEWER');

-- CreateEnum
CREATE TYPE "AccountType" AS ENUM ('CASH', 'BANK', 'CREDIT_CARD', 'DIGITAL_WALLET', 'INVESTMENT', 'SAVINGS', 'LOAN');

-- CreateEnum
CREATE TYPE "TransactionType" AS ENUM ('INCOME', 'EXPENSE', 'TRANSFER');

-- CreateEnum
CREATE TYPE "CategoryType" AS ENUM ('INCOME', 'EXPENSE');

-- CreateEnum
CREATE TYPE "BudgetPeriod" AS ENUM ('WEEKLY', 'MONTHLY', 'YEARLY');

-- CreateEnum
CREATE TYPE "DebtType" AS ENUM ('OWED_BY_ME', 'OWED_TO_ME');

-- CreateEnum
CREATE TYPE "GoalStatus" AS ENUM ('ACTIVE', 'COMPLETED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "RecurrenceFrequency" AS ENUM ('DAILY', 'WEEKLY', 'BIWEEKLY', 'MONTHLY', 'YEARLY');

-- CreateTable
CREATE TABLE "users" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "password_hash" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "avatar_url" TEXT,
    "is_verified" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "refresh_tokens" (
    "id" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "refresh_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "workspaces" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "plan" "Plan" NOT NULL DEFAULT 'FREE',
    "currency" TEXT NOT NULL DEFAULT 'COP',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "workspaces_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "workspace_members" (
    "id" TEXT NOT NULL,
    "workspace_id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "role" "WorkspaceMemberRole" NOT NULL DEFAULT 'MEMBER',
    "joined_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "workspace_members_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "accounts" (
    "id" TEXT NOT NULL,
    "workspace_id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "type" "AccountType" NOT NULL,
    "currency" TEXT NOT NULL DEFAULT 'COP',
    "balance" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "color" TEXT NOT NULL DEFAULT '#6366F1',
    "icon" TEXT NOT NULL DEFAULT 'wallet',
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "accounts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "categories" (
    "id" TEXT NOT NULL,
    "workspace_id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "type" "CategoryType" NOT NULL,
    "parent_id" TEXT,
    "color" TEXT NOT NULL DEFAULT '#6366F1',
    "icon" TEXT NOT NULL DEFAULT 'tag',
    "is_default" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "transactions" (
    "id" TEXT NOT NULL,
    "workspace_id" TEXT NOT NULL,
    "account_id" TEXT NOT NULL,
    "category_id" TEXT,
    "type" "TransactionType" NOT NULL,
    "amount" DECIMAL(18,2) NOT NULL,
    "description" TEXT NOT NULL,
    "date" TIMESTAMP(3) NOT NULL,
    "notes" TEXT,
    "receipt_url" TEXT,
    "transfer_to_account_id" TEXT,
    "transfer_from_account_id" TEXT,
    "recurring_id" TEXT,
    "created_by_id" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "transactions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "recurring_transactions" (
    "id" TEXT NOT NULL,
    "workspace_id" TEXT NOT NULL,
    "frequency" "RecurrenceFrequency" NOT NULL,
    "next_due_date" TIMESTAMP(3) NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "recurring_transactions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "budgets" (
    "id" TEXT NOT NULL,
    "workspace_id" TEXT NOT NULL,
    "category_id" TEXT NOT NULL,
    "amount" DECIMAL(18,2) NOT NULL,
    "period" "BudgetPeriod" NOT NULL DEFAULT 'MONTHLY',
    "start_date" TIMESTAMP(3) NOT NULL,
    "alert_at" INTEGER NOT NULL DEFAULT 80,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "budgets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "savings_goals" (
    "id" TEXT NOT NULL,
    "workspace_id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "target_amount" DECIMAL(18,2) NOT NULL,
    "current_amount" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "deadline" TIMESTAMP(3),
    "color" TEXT NOT NULL DEFAULT '#10B981',
    "icon" TEXT NOT NULL DEFAULT 'target',
    "status" "GoalStatus" NOT NULL DEFAULT 'ACTIVE',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "savings_goals_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "debts" (
    "id" TEXT NOT NULL,
    "workspace_id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "type" "DebtType" NOT NULL,
    "total_amount" DECIMAL(18,2) NOT NULL,
    "remaining_amount" DECIMAL(18,2) NOT NULL,
    "interest_rate" DECIMAL(5,2),
    "installments" INTEGER,
    "payment_day" INTEGER,
    "due_date" TIMESTAMP(3),
    "contact_name" TEXT,
    "notes" TEXT,
    "is_paid" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "debts_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "refresh_tokens_token_key" ON "refresh_tokens"("token");

-- CreateIndex
CREATE UNIQUE INDEX "workspace_members_workspace_id_user_id_key" ON "workspace_members"("workspace_id", "user_id");

-- CreateIndex
CREATE INDEX "transactions_workspace_id_date_idx" ON "transactions"("workspace_id", "date");

-- CreateIndex
CREATE INDEX "transactions_account_id_idx" ON "transactions"("account_id");

-- CreateIndex
CREATE INDEX "transactions_category_id_idx" ON "transactions"("category_id");

-- CreateIndex
CREATE UNIQUE INDEX "budgets_workspace_id_category_id_period_start_date_key" ON "budgets"("workspace_id", "category_id", "period", "start_date");

-- AddForeignKey
ALTER TABLE "refresh_tokens" ADD CONSTRAINT "refresh_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "workspace_members" ADD CONSTRAINT "workspace_members_workspace_id_fkey" FOREIGN KEY ("workspace_id") REFERENCES "workspaces"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "workspace_members" ADD CONSTRAINT "workspace_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "accounts" ADD CONSTRAINT "accounts_workspace_id_fkey" FOREIGN KEY ("workspace_id") REFERENCES "workspaces"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "categories" ADD CONSTRAINT "categories_workspace_id_fkey" FOREIGN KEY ("workspace_id") REFERENCES "workspaces"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "categories" ADD CONSTRAINT "categories_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "categories"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "transactions" ADD CONSTRAINT "transactions_workspace_id_fkey" FOREIGN KEY ("workspace_id") REFERENCES "workspaces"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "transactions" ADD CONSTRAINT "transactions_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "accounts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "transactions" ADD CONSTRAINT "transactions_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "categories"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "transactions" ADD CONSTRAINT "transactions_transfer_to_account_id_fkey" FOREIGN KEY ("transfer_to_account_id") REFERENCES "accounts"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "transactions" ADD CONSTRAINT "transactions_transfer_from_account_id_fkey" FOREIGN KEY ("transfer_from_account_id") REFERENCES "accounts"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "transactions" ADD CONSTRAINT "transactions_recurring_id_fkey" FOREIGN KEY ("recurring_id") REFERENCES "recurring_transactions"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "transactions" ADD CONSTRAINT "transactions_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "recurring_transactions" ADD CONSTRAINT "recurring_transactions_workspace_id_fkey" FOREIGN KEY ("workspace_id") REFERENCES "workspaces"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "budgets" ADD CONSTRAINT "budgets_workspace_id_fkey" FOREIGN KEY ("workspace_id") REFERENCES "workspaces"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "budgets" ADD CONSTRAINT "budgets_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "savings_goals" ADD CONSTRAINT "savings_goals_workspace_id_fkey" FOREIGN KEY ("workspace_id") REFERENCES "workspaces"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "debts" ADD CONSTRAINT "debts_workspace_id_fkey" FOREIGN KEY ("workspace_id") REFERENCES "workspaces"("id") ON DELETE CASCADE ON UPDATE CASCADE;
